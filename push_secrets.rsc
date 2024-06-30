#-------------------------------------------------------------------------------------------------------------------------------------------------------#
#This script permits to copy all secret account of a Mikrotik router to an other one
#The users created on the remote router are them configurer on the router where this script is executed
#-------------------------------------------------------------------------------------------------------------------------------------------------------#
# Set environment parameters
:local remoteIP 10.10.10.2;             # IP address of the remote MikroTik router
:local remoteUser "admin";              # Username for the remote MikroTik router
:local remotePassword "admin";          # Password for the remote MikroTik router
:local localSecretOnly "local-only";    #If this string is present in the comment of a secret account, it won't be transmitted to the remote router
:local useHttps true;                   #set true or false depending on your wish to use https

#Function to get all names from remote router
:global getRemoteSecretNames do={
    # Load library (set library functions to global variables)
    /system/script/run JParseFunctions;
    :global JSONLoads;

    :global data;
    :local url;
    :local transportMode;
    :if ($secureConnection) do={ :set url ("https://" . $rUser . ":" . $rPassword . "@" . $rIP . "/rest/ppp/secret"); set transportMode "https"; } else { :set url ("http://" . $rUser . ":" . $rPassword . "@" . $rIP . "/rest/ppp/secret"); set transportMode "http"; }
    :local result [/tool/fetch mode=$transportMode url=$url output=user as-value];
    :set data ($result->"data");
    #:put $data;
    #:local filename "remote-data.json";
    #/file/add name=$filename contents=$data;
    #:local jsonData [$JSONLoad "remote-data.json"];
    :local jsonData [$JSONLoads $data];
    #:put $jsonData;
    # Initialize an empty array to store the names
    :local remoteSecretNames [];

    # Loop through each element in the JSON array
    :for i from=0 to=([:len $jsonData] - 1) do={
        :local currentElement [:pick $jsonData $i]
        :local nameField ($currentElement->"name")
        #:put $nameField;
        
        # Append the name to the remoteSecretNames
        :set remoteSecretNames ($remoteSecretNames, $nameField)
    }
    :return $remoteSecretNames;
}


# Function to check if a secret exists on the remote router
:global secretExists do={
    :local exists false;
    #:put "entering in secretExist";
    #:put $nameList;
    :foreach item in=$nameList do={
        #:put "$item = $secretName ?";
        :if ($item = $secretName) do={
            :set exists true;
        };
    };
    :return $exists;
}

# Retrieve the list of PPP secrets from the local router
:local localSecrets [/ppp/secret/print detail as-value];

#Get remote secrets
:local remoteSecrets;
:set remoteSecrets [$getRemoteSecretNames rUser=$remoteUser rPassword=$remotePassword rIP=$remoteIP secureConnection=$useHttps];
#:put "remote secrets";
#:put $remoteSecrets;
#:put "end";

:local url;
:local transportMode;
:if ($useHttps) do={ :set url ("https://" . $remoteUser . ":" . $remotePassword . "@" . $remoteIP . "/rest/ppp/secret/add"); set transportMode "https"; } else { :set url ("http://" . $remoteUser . ":" . $remotePassword . "@" . $remoteIP . "/rest/ppp/secret/add"); set transportMode "http"; }


# Loop through each secret and check if it exists on the remote router
:foreach secret in=$localSecrets do={
    :local callerId ($secret->"caller-id");
    :local comment ($secret->"comment");
    :local ipv6Routes ($secret->"ipv6-routes");
    :local limitBytesIn ($secret->"limit-bytes-in");
    :local limitBytesOut ($secret->"limit-bytes-out");
    :local name ($secret->"name");
    :local password ($secret->"password");
    :local profile ($secret->"profile");
    :local remoteAddress ($secret->"remote-address"); #Attention, si le champ est vide, ne pas le fournir !
    :local routes ($secret->"routes");
    :local service ($secret->"service");
    :local remoteAddrIsDefined true;
    #:put $secret;
    #checks if the account should not be transmitted to the remote router
    #:put [:find $comment $localSecretOnly];
    #:put [:typeof [:find $comment $localSecretOnly]];
    :if ([:typeof [:find $comment $localSecretOnly]] = "nil") \
    do={
        :if ([:typeof $remoteAddress] = "nothing") do={ :set remoteAddrIsDefined false; }
        
        # Check if the secret exists on the remote router
        :if ([$secretExists secretName=$name nameList=$remoteSecrets] = false) do={
            # If the secret does not exist, add it to the remote router
            :put ("Adding secret " . $name . " to the remote router")
            :local postData;
            #Ne fournit pas le champ remote-address s'il n'y en n'a pas dans la conf du secret
            :if ( $remoteAddrIsDefined ) \
            do={ :set postData ("{\"caller-id\":\"" . $callerId . "\", \"comment\":\"" . $comment . "\", \"ipv6-routes\":\"" . $ipv6Routes . "\", \"limit-bytes-in\":\"" . $limitBytesIn . "\", \"limit-bytes-out\":\"" . $limitBytesOut . "\", \"name\":\"" . $name . "\", \"password\":\"" . $password . "\", \"profile\":\"" . $profile . "\", \"remote-address\":\"" . $remoteAddress . "\", \"routes\":\"" . $routes . "\", \"service\":\"" . $service . "\"}"); } \
            else={ :set postData ("{\"caller-id\":\"" . $callerId . "\", \"comment\":\"" . $comment . "\", \"ipv6-routes\":\"" . $ipv6Routes . "\", \"limit-bytes-in\":\"" . $limitBytesIn . "\", \"limit-bytes-out\":\"" . $limitBytesOut . "\", \"name\":\"" . $name . "\", \"password\":\"" . $password . "\", \"profile\":\"" . $profile . "\", \"routes\":\"" . $routes . "\", \"service\":\"" . $service . "\"}"); };
            #:put $url;
            #:put $postData;
            /tool/fetch mode=$transportMode url=$url http-method=post http-data=$postData http-header-field="content-type: application/json" output=user as-value;
        } else { :put "$name already exists in remote router !" };
    } else { :put "$name  is a local account !"; }
    
}