use ic_agent::{
	export::Principal,
	ic_types::{hash_tree::LookupResult, HashTree},
	lookup_value, Agent, AgentError, Certificate,
};
use flate2::read::{DeflateDecoder, GzDecoder};
use sha2::{Digest, Sha256};
use hyper::{Uri, body::Bytes};
use crate::ic_req_headers::{HeadersData};
use std::{io::Read};
use ic_utils::{
	interfaces::http_request::{StreamingCallbackHttpResponse, Token},
};
use candid::{
	parser::{
			value::{IDLValue},
	},
	types::{Label},
};

// The limit of a buffer we should decompress ~10mb.
const MAX_CHUNK_SIZE_TO_DECOMPRESS: usize = 1024;
const MAX_CHUNKS_TO_DECOMPRESS: u64 = 10_240;


pub fn validate_chunk(
	callback_response: StreamingCallbackHttpResponse,
	canister_id: Principal,
	agent: &Agent,
	uri: &Uri,
	logger: slog::Logger,
) -> Result<(), String> {
	// let { body, token } = callback_response;
	let fields  = match callback_response.token.clone() {
		Some(Token(IDLValue::Record(fields))) => fields,
		_ => Vec::new(),
	};

	let token_cert = fields.iter().find(|&r| r.id == Label::Id(1_102_915_300));
	let token_tree = fields.iter().find(|&r| r.id == Label::Id(1_292_081_502));
	let token_tree_path = fields.iter().find(|&r| r.id == Label::Id(3_577_787_238));

	if token_cert.is_some() && token_tree.is_some() && token_tree_path.is_some()  {
			let cert_bytes = base64::decode(token_cert.unwrap().val.to_string().replace("\"", "")).unwrap();
			let tree_bytes = base64::decode(token_tree.unwrap().val.to_string().replace("\"", "")).unwrap();
			let tree_path = token_tree_path.unwrap().val.to_string().replace("\"", "");

			let body_valid = validate(
					&HeadersData {
							certificate: Some(Ok(cert_bytes)),
							tree: Some(Ok(tree_bytes)),
							encoding: None,
							key: Some(tree_path),
					},
					&canister_id,
					agent,
					uri,
					&Bytes::from(callback_response.body.clone()),
					logger.clone(),
			);

			slog::info!(
					logger,
					"==[ STREAMING ]==> REQUESTED CHUNK VALID: {:?}",
					body_valid.clone(),
			);
			return body_valid;
	}

	Ok(())
}

pub fn validate(
	headers_data: &HeadersData,
	canister_id: &Principal,
	agent: &Agent,
	uri: &Uri,
	response_body: &[u8],
	logger: slog::Logger,
) -> Result<(), String> {
	let body_sha = if let Some(body_sha) =
			decode_body_to_sha256(response_body, headers_data.encoding.clone())
	{
			body_sha
	} else {
			return Err("Body could not be decoded".into());
	};

	let found_uri = str::replace(uri.path(), &format!("{}{}", "/-/", canister_id).to_string(), "");
	let tree_key = if let Some(tree_key) = headers_data.key.as_ref() { tree_key } else { &found_uri };

	let body_valid = match (
			headers_data.certificate.as_ref(),
			headers_data.tree.as_ref(),
	) {
			(Some(Ok(certificate)), Some(Ok(tree))) => match validate_body(
					Certificates { certificate, tree },
					canister_id,
					agent,
					tree_key.to_string(),
					&body_sha,
					logger.clone(),
			) {
					Ok(true) => Ok(()),
					Ok(false) => Err("Body does not pass verification".to_string()),
					Err(e) => Err(format!("Certificate validation failed: {}", e)),
			},
			(Some(_), _) | (_, Some(_)) => Err("Body does not pass verification".to_string()),

			// TODO: Remove this (FOLLOW-483)
			// Canisters don't have to provide certified variables
			// This should change in the future, grandfathering in current implementations
			(None, None) => Ok(()),
	};

	if body_valid.is_err() && !cfg!(feature = "skip_body_verification") {
			return body_valid;
	}

	Ok(())
}

fn decode_body_to_sha256(body: &[u8], encoding: Option<String>) -> Option<[u8; 32]> {
	let mut sha256 = Sha256::new();
	let mut decoded = [0u8; MAX_CHUNK_SIZE_TO_DECOMPRESS];
	match encoding.as_deref() {
			Some("gzip") => {
					let mut decoder = GzDecoder::new(body);
					for _ in 0..MAX_CHUNKS_TO_DECOMPRESS {
							let bytes = decoder.read(&mut decoded).ok()?;
							if bytes == 0 {
									return Some(sha256.finalize().into());
							}
							sha256.update(&decoded[0..bytes]);
					}
					if decoder.bytes().next().is_some() {
							return None;
					}
			}
			Some("deflate") => {
					let mut decoder = DeflateDecoder::new(body);
					for _ in 0..MAX_CHUNKS_TO_DECOMPRESS {
							let bytes = decoder.read(&mut decoded).ok()?;
							if bytes == 0 {
									return Some(sha256.finalize().into());
							}
							sha256.update(&decoded[0..bytes]);
					}
					if decoder.bytes().next().is_some() {
							return None;
					}
			}
			_ => sha256.update(body),
	};
	Some(sha256.finalize().into())
}

struct Certificates<'a> {
	certificate: &'a Vec<u8>,
	tree: &'a Vec<u8>,
}

fn validate_body(
	certificates: Certificates,
	canister_id: &Principal,
	agent: &Agent,
	tree_key: String,
	body_sha: &[u8; 32],
	logger: slog::Logger,
) -> anyhow::Result<bool> {
	let cert: Certificate =
			serde_cbor::from_slice(certificates.certificate).map_err(AgentError::InvalidCborData)?;
	let tree: HashTree =
			serde_cbor::from_slice(certificates.tree).map_err(AgentError::InvalidCborData)?;

	//TODO: does not pass verification
	// if let Err(e) = agent.verify(&cert, *canister_id, false) {
	//     slog::trace!(logger, ">> certificate failed verification: {}", e);
	//     return Ok(false);
	// }

	let certified_data_path = vec![
			"canister".into(),
			canister_id.into(),
			"certified_data".into(),
	];
	let witness = match lookup_value(&cert, certified_data_path) {
			Ok(witness) => witness,
			Err(e) => {
					slog::trace!(
							logger,
							">> Could not find certified data for this canister in the certificate: {}",
							e
					);
					return Ok(false);
			}
	};
	let digest = tree.digest();

	if witness != digest {
			slog::trace!(
					logger,
					">> witness ({}) did not match digest ({})",
					hex::encode(witness),
					hex::encode(digest)
			);

			return Ok(false);
	}

	let path = ["http_assets".into(), tree_key.into()];
	let tree_sha = match tree.lookup_path(&path) {
			LookupResult::Found(v) => v,
			_ => match tree.lookup_path(&["http_assets".into(), "/index.html".into()]) {
					LookupResult::Found(v) => v,
					_ => {
							slog::trace!(
									logger,
									">> Invalid Tree in the header. Does not contain path {:?}",
									path
							);
							return Ok(false);
					}
			},
	};

	Ok(body_sha == tree_sha)
}

