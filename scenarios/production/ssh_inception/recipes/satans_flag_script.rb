script "statans_flag_script" do
  interpreter "bash"
  user "root"
  cwd "/tmp"
 code <<-EOH
  echo "Ax qgmnw vjghhwv s kzwdd sfv sjw jwsvafy lzak, qgmnw vwxwslwv lzw xafsd wfweq sfv ogf lzw ysew. Ugfyjslmdslagfk." > /home/satan/final_flag
  cd /tmp
  touch satans_flag
  EOH
  not_if "test -e /tmp/satans_flag"
end