
###The LaunchDaemon 
Needs to be installed in /Library/LaunchDaemons  
owner should be root:wheel  
Permissing should be 644  

###The LaunchAgent
Should be installed in /Library/LaunchAgents  
Permission should be 644  

To user the launch Agent the FileVault Setup.app needs to be in the /Applications/ folder.
If you want to place it somewhere else, modify the LaunchAgent accordingly.

right now the launch agent calls a script to open the FVS.app rather than directly calling the App's executalbe.  If LaunchD calls the app's exec directly it won't allow Mach messaging to the helper tool.  
 

###The helper binary 
Should be installed in /Library/PrivilegedHelperTools/


### Notes on Code Signing
This is currently set up for code signing, althought it works w/o.  
You will need to create a Code signing certificate named Mac Developer. 

You'll also want to change the FVSHelper-Info.plist and FileVault Setup-Info.plist  
to correctly represent your Certificate Leaf.  
in the  

	"Clients allowed to add and remove tool" 
	
and
		
	 "Tools owned after installation"
	 
section respectivly.  The best way I've found to do this is by following the instructions in the [SMJobBless example code](http://developer.apple.com/library/mac/#samplecode/SMJobBless/Listings/ReadMe_txt.html) and step throught setup instructions there and run the SMJobBlessUtil.py  

This is unnecessary and merely set up for the possible inclusion of SMJobBless down the road.
This should work w/o code signing entirely.  If you wish to cleanly disable CS entirely 
you can remove the "Other Link Flags" section of Build Settings for the helper. 
