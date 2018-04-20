# User Defined Policy allowing API Connect to interact with MQ

*https://www.ibm.com/developerworks/library/mw-1611-hutchinson-trs/index.html*

The purpose of this tool is to use a custom policy to integrate an instance of API Connect with an MQ Queue Manager.

## How do I use it 

    • Pull this repository down onto your machine
    • Run the build script against the policy folder
    
    charlottehutchinson@CharlottesMBP2:~/APIConnect-MQ-UDP$ sh package_dp_policy.sh -d mqinvoke-source/
    
    • In an API Connect catalog visit settings/policies
    • Select the zip file that is created by the build process to import to API Connect 


## MQ UDP
#####Queuemanager 
This variable should be set to the name value for the IBM MQ Queue Manager Object or IBM MQ Queue Manager Group Object in IBM Datapower. 

#####Queue
This variable should be set to the name of the desired request queue within the queue manager selected above.

#####Replyqueue
This variable should be set to the name of the desired reply queue within the queue manager selected above. If the message flow is not intended to be synchronous this value should be left null or “”

#####Backoutq
If needed, this variable should be set to the name of the desired back out queue within the queue manager selected above. If set to null or “” the policy will not place bad messages onto the backout queue. The backout queue must be defined here and not in the datapower MQ object. 

#####Timeout
The time, in milliseconds, after which the policy will declare the queue manager unreachable, returning a 408 timeout reached response code.

## Policies guidelines

    Each policy should have it's own subdirectory within this directory
    The subdirectory should share the name of the custom policy (as defined in the policy.yaml name attribute)
    Each policy folder should contain all the constituent files AND a .zip file for import into API Connect
    The policy subdirectory should have the following structure
        mypolicy
        |
        ⌊ --> implementation
        |          |
        |          ⌊ --> {implementation files/folders}
        |
        ⌊ --> mypolicy.yaml

## The build script

To produce a valid zip file please run the following commmand
`sh build.sh . mqinvoke`

