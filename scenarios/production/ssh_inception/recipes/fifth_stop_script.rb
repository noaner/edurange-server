script "fifth_stop_script" do
  interpreter "bash"
  user "root"
  cwd "/tmp"
 code <<-EOH
  echo "WW91IGZvdW5kIG1lLiBHb29kIGpvYi4gVGhlIG5leHQgY2hhbGxlbmdlIHdpbGwgbm90IGJlIHNvIGVhc3kuIFlvdSB3aWxsIGZpbmQgU2F0YW5zIFBhbGFjZSBvbiB0aGUgaG9zdCB3aXRoIGEgY2VydGFpbiBvcGVuIHBvcnQuIFRoZSBtb3N0IGV2aWwgb3BlbiBwb3J0LiBTU0ggdG8gdGhhdCBwb3J0IHdpdGggdGhlIHVzZXIgc2F0YW4gYW5kIHRoZSBwYXNzd29yZCBoZWxsX2lzX3RoZV9kZWVwZXN0X2xldmVsLiBUaGUgZmluYWwgdHJlYXN1cmUgYXdhaXRzLi4u" > /home/neo/betcha_cant_read_me
  chmod 444 /home/neo/betcha_cant_read_me
  touch /tmp/recipe-fifth-stop-done
  EOH
  not_if "test -e /tmp/recipe-fifth-stop-done"
end