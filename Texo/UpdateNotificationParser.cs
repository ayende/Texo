using System.IO;
using System.Text;
using Newtonsoft.Json;
using Newtonsoft.Json.Linq;

namespace Texo
{
	public class UpdateNotificationParser
	{
		public UpdateNotificationParser(string payload)
		{
			var reader = new JsonTextReader(new StringReader(payload));
			var update = (JObject) new JsonSerializer().Deserialize(reader);
			Url = update["repository"]["url"].Value<string>();

			var sb = new StringBuilder();

			foreach (JObject commit in update["commits"])
			{
				var id = commit["id"].Value<string>().Substring(0,7);
				var msg = commit["message"].Value<string>();
				sb.Append(id).Append(" ").AppendLine(msg);
			}

			PushMessage = sb.ToString();
		}

		public string PushMessage { get; private set; }
		public string Url { get; set; }
	}
}