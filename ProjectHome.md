TAutoUpdate is an Object Pascal Class created with the sole objective of easily adding Auto Update capability to Delphi/FreePascal applications.

## Features ##

  * Easy to implement (only one unit).
  * Allows retrieval of updates from FTP servers.
  * Allows retrieval of updates from HTTP servers.

## Example ##

1) Create the file update.ini in the same folder as the main application.

2) Contents of update.ini
```
[default]
updatefile=/etc/updateinfo.ini
method=ftp
[params]
host=myhost.com
port=21
user=myusername
pass=mypassword
```

This connects to the ftp server and looks for the file /etc/updateinfo.ini
who tells  TAutoUpdate where is the update zip file containing all the new files,
then the file is unzipped and executes update.exe, the file in charge
of upgrading the program.

3) Contents of updateinfo.ini:

```
[default]
installer=install.zip
```

4) Execute TAutoUpdate to update your program:

```
with TAutoUpdate.Create('update.ini') do
begin
  Execute;
  Free;
end;
```

## External libraries used ##

[Abbrevia](http://sourceforge.net/projects/tpabbrevia) for unzip files.

[Synapse](http://synapse.ararat.cz/) for Http/Ftp downloading.

## Developer ##

http://leonardorame.blogspot.com