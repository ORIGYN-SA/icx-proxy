# Execute from specific dir
rm -rf global_locals.tf  global_vars.tf provider.tf
ln -s ../global_locals.tf global_locals.tf
ln -s ../global_vars.tf global_vars.tf
ln -s ../provider.tf provider.tf