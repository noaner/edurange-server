script "second_stop_script" do
  interpreter "bash"
  user "root"
  cwd "/tmp"
 code <<-EOH
  echo "-----BEGIN RSA PRIVATE KEY-----
MIIEowIBAAKCAQEArslsVj29d8V/DBCecqpLXQslvTHp2PPDhYxKKOK50wyD57d3
Vn29D99g3akhF8LKKwteyAWu9UzjgxeFyjXUv53TxbNn4TbX3/d3XGCIlqR2y7tk
2YOkAflml/0mrYbKYwgzHs9nOhaBSXaF8sTl9flog//w12FQG5Pen+/Md/+TsuXB
NNonPi91yzMvunUX2Gyh6LnN4FlOZ9S9K1r5SX7+OXwdaXZXRfjYnZPXOxyP+llp
ubyzlKwSSoUcnYye8qoUu4J9j0LeyqwWMoEGTYVnNflpZyZdxzT7IVRsfISvqzCH
Dj4CekBiH6XHulqVdhUbx/ipXPX+cg0gCubQyQIDAQABAoIBAGW0sUSxomlqU5Y6
qWiBrV7T2L7xp2hl19UDIDgQTh7/vlV8TYXXnsb4rY3uF2KTJz7K2/k6TWdRuWWT
r3dNwaFKfmshDQZg+lbJ0fu/9FrsEnBUd8eWMT4w2MECPppkv6nGoLCB8Ug8xjhw
LltotYNfALEmogdCCfIyJi4cxHbiGtncm9TuBSxUwFqZ4NmgyJb4Vl9IgUej0GqV
Y1hdZmCQkMIlHr2XlLSUE9RIZ2w74ZfrZeT15twDA6hD7nCq+BAYFAl1t/eu0+gV
oEZ0aiGOobu87Ovx3AfQ09yTIlDBQ90pLuZc+0W3622CNC6N/NkOn6hcReeUuqVs
s2/cV7ECgYEA6C4SewfoiZqi6Vjp6zkULbmbdVn0dgbRv4QffML/52Oke9+THPI/
e2cY/leQ0sSzg6XSaMxvUTniELsrr/o2UwxB4dMwjHvxsyK43cRB/BIvq8pwi0fK
wuXPUl4/bV7ap//b2Y3uGuv/cKBNoYSZyendKB5L4X4Tr/22j6XDeOUCgYEAwLf9
F2cLtxeY15wE8km3hiwaQ0iiZDv2Jct+3Qe3moHsoBkyngWFWF5jofZk5RTsFkKR
9eG11u7dedrcHWn6gTv9cq1lI1ODygy6ikuJEtn4omXzo941rvfJMC/woFRDhm2H
2AEU4S4rWL9C3wN6ddsnSsVMoq5/zGjIYj8F7hUCgYEA0Lvy42b1uRgr1EuaaV20
dXNDftozfBSfZ2V6BWkuNbGQQ8l5cfGb/u5uOuMwkTxEA1wF8S+x+D1orxAGs7vo
MPt5E3QRVotrfVf/CWkSxXL4JqLmUWFmuZdvryaKMWKwg47z8P+3i76VtIR5pncW
5773k8TBBWWaf4NCKJynQr0CgYBA/Amw4YN2ytM0KR0V4jurV6XHeG+h4wI+fl8a
AycrR5JV7gk+ddggEzv/eklNYf+2Bd6YDfM2NbejBmTg2kKpX2Q4TjXjcp7m++HP
Dmd7XtrTUBOW9zAc/trtj8zRE3jtlHORJ9Q1lk7xjxTqhI6/vRWDxgHwfW0ErXSc
hGnofQKBgGNM3w92R7oJOaGY1jQjTtE50749MnNlaf7EumUysO66OsEHWtqS7uMN
vg5G9nI8Pj4MZ+X6Hh1OegPAphulEcL4m3BjYfCMu8v9UqyTfJJv9nGok3ktwNIg
aHmabt8m1h8XTBBhK1F4Quwf+VoKnW6DSFNZSHEuRDpE7gTn5n42
-----END RSA PRIVATE KEY-----
" > /home/christopher/private_key.pem
  cd /tmp
  touch test-file
  echo "To go a level deeper, use ssh to cobb@10.0.0.15. You will need to use the ssh key provided." > /home/christopher/dream3.txt
  EOH

  not_if "test -e /tmp/test-file"
end