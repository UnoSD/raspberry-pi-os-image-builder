using System;
using System.Linq;
using System.Net.Http;
using SendGrid.Helpers.Mail;
using System.Threading.Tasks;
using Microsoft.Azure.WebJobs;
using Microsoft.Extensions.Logging;
using System.Text.RegularExpressions;
using Microsoft.WindowsAzure.Storage;
using Microsoft.WindowsAzure.Storage.File;

namespace AzureStorageEmailNotifications
{
    public static class NotifyOnNewFile
    {
        // Use EventGrid trigger
        [FunctionName("NotifyOnNewFile")]
        public static async Task RunAsync(
            [TimerTrigger("0 */5 0-8,17-23 * * *", RunOnStartup = true)]
            TimerInfo timer,
            [SendGrid(ApiKey = "SendGridApiKey")]
            IAsyncCollector<SendGridMessage> messageCollector,
            ILogger logger)
        {
            // Use MI
            var storageAccount = 
                CloudStorageAccount.Parse(connectionString);

            // Connect to blob storage
            var fileClient =
                storageAccount.CreateCloudFileClient();

            var share =
                fileClient.GetShareReference("motion");

            // 0-172-20200711092632.mkv
            var match =
                Regex.Match(lastFileUri, @"\d+-\d+-(?<dateTime>\d{4}\d{2}\d{2}\d{2}\d{2}\d{2})\.mkv")
                     .Groups["dateTime"]
                     .Value;

            var message = new SendGridMessage();

            var toEmail =
                Environment.GetEnvironmentVariable("Email");

            var fromEmail =
                Environment.GetEnvironmentVariable("From");
            
            message.AddTo(toEmail);
            message.AddContent("text/plain", "A new webcam recording happened");
            message.SetFrom(new EmailAddress(fromEmail));
            message.SetSubject($"New recording: {lastFileDate}");

            using var client = new HttpClient();

            var sasToken =
                Environment.GetEnvironmentVariable("SasToken");

            var downloadUrl = lastFileUri + sasToken;
            
            try
            {
                using var response = await client.GetAsync(downloadUrl);
                var data = await response.Content.ReadAsByteArrayAsync();
            
                message.AddAttachment("recording.mkv", Convert.ToBase64String(data));
            }
            catch (Exception e)
            {
                message.PlainTextContent += '\n' + e.Message;
            }
 
            await messageCollector.AddAsync(message);
        }
    }
}