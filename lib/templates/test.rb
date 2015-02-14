

ruby_block "finish" do
  block do
    put = Net::HTTP::Put.new(open(@scoring_url).read.chomp, {
'content-type' => 'text/plain',
})
  end
  action :action
end

