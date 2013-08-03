# ZacharyKamerling@gmail.com
# D/M/Y = 2/10/13
#-------------------------------------------
# example usage: ruby Merger.rb Hello A B C
# where Hello = output file name
#       A,B,C = input file names
#-------------------------------------------

def merge(itxts)
  txts = itxts.map do |t| 
    file = File.new(t,"r")
    txt = Array.new
    while (line = file.gets) do
      txt.push(line)
    end
    txt
  end
  new_txt = Array.new
  while (txts.all? { |t| not(t.empty?) }) do
    for t in txts do
      r = rand(0..2)
      new_txt.concat(t[0..r])
      t.slice!(0..r)
    end
  end
  new_txt.map do |t|
    t.to_s
  end
end

file = File.new(ARGV[0],"w")
file.puts(merge(ARGV.drop(1)))
file.close
