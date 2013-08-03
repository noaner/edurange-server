package 'binutils'
cookbook_file "/tmp/gen_iofhowhfio" do
  source "gen"
  mode 00755
end

execute "generate strace log" do
  command "/tmp/gen_iofhowhfio"
  creates "/tmp/sorted"
  action :run
end
