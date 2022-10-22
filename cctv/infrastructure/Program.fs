module Program

open Pulumi.FSharp.AzureNative.Storage.Inputs
open Pulumi.FSharp.AzureNative.Resources
open Pulumi.FSharp.AzureNative.Storage
open Pulumi.AzureNative.Storage
open Pulumi.FSharp.NamingConventions.Azure.Resource
open Pulumi.FSharp.NamingConventions.Azure
open Pulumi.FSharp
open Pulumi.FSharp.Config
open Pulumi
open Pulumi.FSharp.Command.Local
open Pulumi.AzureNative.Authorization
open Pulumi.FSharp.Tls

Deployment.run (fun () ->
    let group =
        resourceGroup { name (nameOne "rg") }

    let storage =
        storageAccount {
            name          $"""sa{config["workloadOrApplication"]}{Deployment.Instance.StackName}{Region.shortName}001"""
            resourceGroup group.Name
            sku           { name SkuName.Standard_LRS }
            kind          Kind.StorageV2
            isHnsEnabled  true
        }
    
    let container =
        blobContainer {
            accountName   storage.Name
            resourceGroup group.Name
            containerName "motion"
            name          (nameOne "container")
            
            PublicAccess.None
        }
    
    let subscriptionId =
        GetClientConfig.InvokeAsync().Result.SubscriptionId
    
    let setSftpUrl = Output.Format($"https://management.azure.com/subscriptions/{subscriptionId}/resourceGroups/{group.Name}/providers/Microsoft.Storage/storageAccounts/{storage.Name}?api-version=2021-09-01")
    let setSftpBody enabled = $""" "{{ "properties": {{ "isSftpEnabled": %b{enabled} }} }}" """
    let setSftpCliCommand enabled = Output.Format($"az rest --method PATCH --body {setSftpBody enabled} --url {setSftpUrl} --headers Content-Type=application/json")
    
    command {
        name   (nameOne "sasftp")
        create (setSftpCliCommand true)
        delete (setSftpCliCommand false)
    }
    
    let sshPrivateKey =
        privateKey {
            name      (nameOne "pk")
            algorithm "RSA"
        }
    
    localUser {
        name          (nameOne "lu")
        resourceGroup group.Name
        accountName   storage.Name
        hasSshKey     true
        username      config["username"]
        //homeDirectory "/" // Should help remove the container name from the username, but did not work
        
        permissionScopes [
            permissionScope {
                resourceName container.Name
                permissions  "crwdl"
                service      "blob"
            }
        ]
        
        sshAuthorizedKeys [
            sshPublicKey {
                key sshPrivateKey.PublicKeyOpenssh
            }
        ]
    }
    
    // pulumi stack output PrivateKey --show-secrets > pk
    // chmod go-rwx pk
    // sftp -o "PubkeyAcceptedKeyTypes=+ssh-rsa" -i pk ACCOUNT.CONTAINER.USERNAME@ACCOUNT.blob.core.windows.net
    // fstab: llib@192.168.1.200:/home/llib/FAH /media/FAH2 fuse.sshfs defaults,_netdev 0 0
    // fstab: user@host:/remote/path /local/path  fuse.sshfs noauto,x-systemd.automount,_netdev,user,idmap=user,follow_symlinks,identityfile=/home/user/.ssh/id_rsa,allow_other,default_permissions,uid=USER_ID_N,gid=USER_GID_N 0 0
    dict [ "PrivateKey", sshPrivateKey.PrivateKeyOpenssh
           "PublicKey" , sshPrivateKey.PublicKeyOpenssh  ]
)