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
open Pulumi.FSharp.Outputs
open Pulumi.FSharp.AzureNative.Web.Inputs
open Pulumi.FSharp.AzureNative.Web

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
    
    let subId =
        GetClientConfig.InvokeAsync().Result.SubscriptionId
    
    let setSftpUrl = Output.Format($"https://management.azure.com/subscriptions/{subId}/resourceGroups/{group.Name}/providers/Microsoft.Storage/storageAccounts/{storage.Name}?api-version=2021-09-01")
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

    let triggers = $"""{{
        "{triggerName}": {{
            "inputs": {{
                "schema": {{
                    "items": {{
                        "properties": {{
                            "data": {{
                                "properties": {{
                                    "blobUrl": {{
                                        "type": "string"
                                    }}
                                }},
                                "type": "object"
                            }}
                        }},
                        "required": [
                            "data"
                        ],
                        "type": "object"
                    }},
                    "type": "array"
                }}
            }},
            "kind": "Http",
            "type": "Request"
        }}
    }}"""

    let blobConnection =
        let accessKey =
            ListStorageAccountKeys.Invoke(ListStorageAccountKeysInvokeArgs(
                AccountName       = storage.Name,
                ResourceGroupName = group.Name))
                                  .Apply(fun x -> x.Keys[0].Value)
        
        connection {
            resourceGroup group.Name
            name          (nameOne "con-azureblob")
            
            apiConnectionDefinitionProperties {
                apiReference {
                    id (Output.Format($"/subscriptions/{subId}/providers/Microsoft.Web/locations/{group.Location}/managedApis/azureblob"))
                }
                
                parameterValues [
                    "accountName", storage.Name
                    "accessKey"  , accessKey
                ]
            }
        }

    let emailConnection =
        let subId = subId
        
        connection {
            resourceGroup group.Name
            name          (nameOne "con-office365")
            
            apiConnectionDefinitionProperties {
                apiReference {
                    id (Output.Format($"/subscriptions/{subId}/providers/Microsoft.Web/locations/{group.Location}/managedApis/office365"))
                }
            }
        }

    // Create typed Logic App actions,
    // Find the schema and generate
    // types with JsonProvider (possibly even computational expressions)
    let workflowDefinition =
        output {
            let! storageName = storage.Name
            let! blobConnectionName = blobConnection.Name
            let! emailConnectionName = emailConnection.Name
            let email = config["notificationEmail"]
            
            let blobAsolutePathLength = $"https://{storageName}.blob.core.windows.net/".Length
            
            let actions =
                $"""{{
           "Create SAS URL to update content type": {{
                "inputs": {{
                    "body": {{
                        "Permissions": "Write"
                    }},
                    "host": {{
                        "connection": {{
                            "name": "@parameters('$connections')['{blobConnectionName}']['connectionId']"
                        }}
                    }},
                    "method": "post",
                    "path": "/v2/datasets/AccountNameFromSettings/CreateSharedLinkByPath",
                    "queries": {{
                        "path": "@{{substring(triggerBody()[0].data.blobUrl, parameters('blobBaseUrlLength'))}}"
                    }}
                }},
                "runAfter": {{}},
                "type": "ApiConnection"
            }},
            "Update blob content type to video": {{
                "inputs": {{
                    "headers": {{
                        "Content-Length": "0",
                        "x-ms-blob-content-type": "video/mp4"
                    }},
                    "method": "PUT",
                    "uri": "@{{body('Create SAS URL to update content type')?['WebUrl']}}&comp=properties"
                }},
                "runAfter": {{
                    "Create SAS URL to update content type": [ "Succeeded" ]
                }},
                "type": "Http"
            }},
            "Generate SAS URL": {{
                "inputs": {{
                    "body": {{
                        "Permissions": "Read"
                    }},
                    "host": {{
                        "connection": {{
                            "name": "@parameters('$connections')['{blobConnectionName}']['connectionId']"
                        }}
                    }},
                    "method": "post",
                    "path": "/v2/datasets/AccountNameFromSettings/CreateSharedLinkByPath",
                    "queries": {{
                        "path": "@{{substring(triggerBody()[0].data.blobUrl, parameters('blobBaseUrlLength'))}}"
                    }}
                }},
                "runAfter": {{
                    "Update blob content type to video": [ "Succeeded" ]
                }},
                "type": "ApiConnection"
            }},
            "Send email": {{
                "inputs": {{
                    "body": {{
                        "Body": "<p>@{{body('Generate SAS URL')?['WebUrl']}}</p>",
                        "Importance": "Normal",
                        "Subject": "Camera motion detected",
                        "To": "{email}"
                    }},
                    "host": {{
                        "connection": {{
                            "name": "@parameters('$connections')['{emailConnectionName}']['connectionId']"
                        }}
                    }},
                    "method": "post",
                    "path": "/v2/Mail"
                }},
                "runAfter": {{
                    "Generate SAS URL": [ "Succeeded" ]
                }},
                "type": "ApiConnection"
            }}
        }}"""
            
            let parameters =
                $"""{{
    "$connections": {{
        "defaultValue": {{}},
        "type": "Object"
    }},
    "blobBaseUrlLength": {{
        "defaultValue": {blobAsolutePathLength},
        "type": "Int"
    }}
}}"""
            
            return $"""{{
    "$schema": "https://schema.management.azure.com/providers/Microsoft.Logic/schemas/2016-06-01/workflowdefinition.json#",
    "actions": {actions},
    "parameters": {parameters},
    "triggers": {triggers}
}}"""
        }
    
    let toConnectionParameter (connection : AzureNative.Web.Connection) =
        output {
            let! connectionId = connection.Id
            let! connectionProperties = connection.Properties
            let! connectionName = connection.Name
            
            return $"""
                "{connectionName}": {{
                    "connectionId": "{connectionId}",
                    "connectionName": "{connectionName}",
                    "id": "{connectionProperties.Api.Id}"
                }}"""
        }
    
    let connections =
        output {
            let! blobConnection = blobConnection |> toConnectionParameter
            let! emailConnection = emailConnection |> toConnectionParameter
            
            return $"""{{
                {blobConnection},
                {emailConnection}
            }}"""
        }
        |> InputJson.op_Implicit
        |> fun cs -> Inputs.workflowParameter { resourceType ParameterType.Object; value cs }
    
    // Add MI
    let logicApp =
        workflow {
            name          (nameOne "logic")
            resourceGroup group.Name
            //managedServiceIdentity { resourceType ManagedServiceIdentityType.SystemAssigned }
            parameters [
            //    "storage-account-name", Inputs.workflowParameter { value "" }
                "$connections"        , connections
            ]
            definition (workflowDefinition |> InputJson.op_Implicit)
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
    
    dict [ "PrivateKey", sshPrivateKey.PrivateKeyOpenssh
           "Test"      , testCommand 
           "PublicKey" , sshPrivateKey.PublicKeyOpenssh ]
)