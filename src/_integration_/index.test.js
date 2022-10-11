// CODE For Testing Http requests to canisters through the icx-proxy and phonebook
import MD5 from 'crypto-js/md5'
const NFT_CANISTER_ID = process.env?.NFT_CANISTER_ID ?? 'rrkah-fqaaa-aaaaa-aaaaq-cai';
const PROXY_PORT = process.env?.PROXY_PORT ?? 3000;
const REPLICA_PORT = process.env?.REPLICA_PORT ?? 8000;


const assets = [{
    collection_name: 'bm-0',
    asset_id: 'brain.matters.nft0.png',
    pb_id: 'bm',
    file: 'nft0.png'
}]

function generateURLs(pb_id, collection_name, asset_id) {
    const direct = `${NFT_CANISTER_ID}.localhost:${REPLICA_PORT}/-/${collection_name}/-/${asset_id}`
    const proxy = `http://localhost:${PROXY_PORT}/-/${NFT_CANISTER_ID}/-/${collection_name}/-/${asset_id}`
    const phonebook = `http://localhost:${PROXY_PORT}/-/${pb_id}/-/${collection_name}/-/${asset_id}`
    return { direct, proxy, phonebook }
}

test('Resources are accessbile from direct, proxy and phonebook', async () => {
    async function checkAsset(asset) {
        const { direct, proxy, phonebook } = generateURLs(asset.pb_id, asset.collection_name, asset.asset_id);
        const fileBuffer = fs.readFileSync(`.test_assets/${asset.file}`).buffer;
        const fileMD5 = MD5(fileBuffer).toString();

        const directResponse = async () => MD5((await fetch(direct)).arrayBuffer()).toString();
        const proxyResponse = async () => MD5((await fetch(proxy)).arrayBuffer()).toString();
        const phonebookResponse = async () => MD5((await fetch(phonebook)).arrayBuffer()).toString();

        return await asyncEvery(
            [directResponse, proxyResponse, phonebookResponse],
            async (responseFunction) => {
                return await responseFunction() === fileMD5;
            })
    }

    expect(await asyncEvery(assets, checkAsset)).toBe(true)
})

const asyncEvery = async (arr, predicate) => {
    for (const el of arr) {
        if (!await predicate(el)) {
            return false
        }
    }
    return true
}
// Try below using direct, proxy and phonebook URLs

// Get hash of actual image
// request image from url
// compare hash

//get hash of streaming gif > 2mb
//request gif from url
//compare streaming hash

