#ssh inception notes

#### Getting to Starting Line
Using the credentials provided by the instructor, players ssh to the nat
then ssh from the nat to Starting Line.

#### Starting line to First Stop
Students must use a different port (ssh -p PORTNUM )

#### First Stop to Second Stop
Students must use nmap to find the right IP address for the  next server. They
can find their subnet by using ifconfig.

#### Second Stop to Third Stop
Students must use a public key pair (shh -i IDENTITY_FILE)


#### Third Stop to Fourth Stop
Third stop has two phases. First, they need to use grep or find to search through
the directory for the hidden credentials.

Students cannot access Third Stop from Second Stop, because Third stop is
blocking the IP of Second Stop. They must ssh to Third stop from First Stop
or Starting Line.

#### Fourth Stop to Fifth Stop
Students must find the ftp server using nmap, and then login using Anonymous  as the
username and no password. Then they can download the credentials. 

#### Fifth Stop to Satan's Palace
Students will be immediately logged out when they connect to Satan's Palace. They need
to use single commands using ssh (ssh USER@HOST command) to find and decrypt the flag.

###TODO

- [ ] Add level where students create a key pair and add their key to a server
- [ ] Move Starting Line to a new subnet that is publically accessible so that 
  students don't have to log into the NAT first. 
- [ ] Fix chef script problems on NAT
