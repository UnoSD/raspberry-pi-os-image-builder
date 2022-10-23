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
open Pulumi.FSharp.AzureNative.EventGrid.Inputs
open Pulumi.FSharp.AzureNative.EventGrid
open Pulumi.AzureNative.EventGrid.Inputs
open Pulumi.AzureNative.Logic
open Pulumi.FSharp.AzureNative.Logic

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
    
    let triggerName =
        "manual"
    
    let logicApp =
        workflow {
            name          (nameOne "logic")
            resourceGroup group.Name
            //managedServiceIdentity { resourceType ManagedServiceIdentityType.SystemAssigned }
            definition    ($"""{{
    "$schema": "https://schema.management.azure.com/providers/Microsoft.Logic/schemas/2016-06-01/workflowdefinition.json#",
    "actions": {{}},
    "contentVersion": "1.0.0.0",
    "outputs": {{}},
    "parameters": {{}},
    "triggers": {{
        "{triggerName}": {{
            "inputs": {{
                "schema": {{}}
            }},
            "kind": "Http",
            "type": "Request"
        }}
    }}
}}""" |> InputJson.op_Implicit)
        }
    
    let triggerUrl =
        ListWorkflowTriggerCallbackUrl.Invoke(ListWorkflowTriggerCallbackUrlInvokeArgs(
            ResourceGroupName = group.Name,
            WorkflowName      = logicApp.Name,
            TriggerName       = triggerName
        )).Apply(fun x -> x.Value)
    
    let topic =
        systemTopic {
            name          (nameOne "evgt")
            resourceGroup group.Name
            source        storage.Id
            topicType     "Microsoft.Storage.StorageAccounts"
        }
    
    systemTopicEventSubscription {
        name            (nameOne "evgs")
        systemTopicName topic.Name
        resourceGroup   group.Name
        
        eventSubscriptionFilter {
            includedEventTypes [
                "Microsoft.Storage.BlobCreated"
            ]
            
            advancedFilters (
                StringInAdvancedFilterArgs(Key = "data.api",
                                           Values = inputList [ input "SftpCommit" ],
                                           OperatorType = "StringIn")
            )
        }
        
        destination (WebHookEventSubscriptionDestinationArgs(
            EndpointType                           = "WebHook",
            EndpointUrl                            = triggerUrl,
            AzureActiveDirectoryApplicationIdOrUri = null,
            AzureActiveDirectoryTenantId           = null
        ))
    }
    
    let testCommand =
        Output.Format($"""pulumi stack output PrivateKey --show-secrets > pk && chmod go-rwx pk && scp -o "PubkeyAcceptedKeyTypes=+ssh-rsa" -i pk Program.fs {storage.Name}.{container.Name}.{config["username"]}@{storage.Name}.blob.core.windows.net:/; rm pk""")
    
    // fstab: user@host:/remote/path /local/path fuse.sshfs noauto,x-systemd.automount,_netdev,user,idmap=user,follow_symlinks,identityfile=/home/user/.ssh/id_rsa,allow_other,default_permissions,uid=USER_ID_N,gid=USER_GID_N 0 0
    dict [ "PrivateKey", sshPrivateKey.PrivateKeyOpenssh
           "Test"      , testCommand 
           "PublicKey" , sshPrivateKey.PublicKeyOpenssh ]
)