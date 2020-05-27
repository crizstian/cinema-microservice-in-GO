exec {
  command = "nginx -g 'daemon off;'"
}

// vault {
//   address = "https://active.vault.service:8200"
// }

reload_signal = "SIGHUP"
