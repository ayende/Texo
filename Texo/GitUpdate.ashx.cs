using System;
using System.Configuration;
using System.Diagnostics;
using System.IO;
using System.Security;
using System.Threading;
using System.Web;

namespace Texo
{
	public class GitUpdate : IHttpHandler
	{
		public void ProcessRequest(HttpContext context)
		{
			var payload = context.Request.Form["payload"];

			var notification = new UpdateNotificationParser(payload);

			var processStartInfo = new ProcessStartInfo
			{
				FileName = "powershell.exe",
				Arguments = ".\\builder.ps1 -url \"" + notification.Url + "\" -ref \""+notification.Ref +"\"",
				WorkingDirectory = AppDomain.CurrentDomain.BaseDirectory,
				UseShellExecute = false,
				RedirectStandardOutput = true,
			};
			processStartInfo.EnvironmentVariables.Add("push_msg", notification.PushMessage);
			var process = Process.Start(processStartInfo);

			var fileName = Path.Combine(Path.Combine(AppDomain.CurrentDomain.BaseDirectory, "logs"), Path.GetFileName(new Uri(notification.Url).AbsolutePath) + "_build.log"); 
			File.WriteAllText(fileName, "Starting build for "+ notification.Url +" at "+DateTime.Now + "PID: " + process.Id + Environment.NewLine);
			new Thread(() =>
			{
				string output;
				while((output = process.StandardOutput.ReadLine()) != null)
				{
					File.AppendAllText(fileName, output + Environment.NewLine);
				}
			})
			{
				IsBackground = true,
				Name = notification.Url
			}.Start();

			context.Response.Write("Build started");
		}

		public bool IsReusable
		{
			get
			{
				return false;
			}
		}
	}
}
