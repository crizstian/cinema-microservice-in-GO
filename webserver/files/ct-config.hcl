exec {
  command = "nginx -g 'daemon off;'"
}

reload_signal = "SIGHUP"
