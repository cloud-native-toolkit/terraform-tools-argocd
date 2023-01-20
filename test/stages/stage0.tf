
data clis_check test_clis {
  clis = ["kubectl", "oc", "argocd"]
}

resource local_file bin_dir {
  filename = "${path.cwd}/.bin_dir"

  content = data.clis_check.test_clis.bin_dir
}
