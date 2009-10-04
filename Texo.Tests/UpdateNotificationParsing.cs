using System;
using System.IO;
using System.Reflection;
using Xunit;

namespace Texo.Tests
{
	public class UpdateNotificationParsing
	{
		private readonly UpdateNotificationParser update;

		public UpdateNotificationParsing()
		{
			using(var stream = Assembly.GetExecutingAssembly().GetManifestResourceStream("Texo.Tests.Payload.json"))
			{
				var payload = new StreamReader(stream).ReadToEnd();
				update = new UpdateNotificationParser(payload);
			}
		}

		[Fact]
		public void CanParseLastCommit()
		{
			Assert.Equal("de8251ff97ee194a289832576287d6f8ad74e3d0", update.LastCommit);
		}

		[Fact]
		public void CanParseRef()
		{
			Assert.Equal("refs/heads/master", update.Ref);
		}

		[Fact]
		public void CanParseUrl()
		{
			Assert.Equal("http://github.com/defunkt/github", update.Url);
		}


		[Fact]
		public void CanParseCommits()
		{
			Assert.Equal(2, update.Commits.Length);
			Assert.Equal("Chris Wanstrath", update.Commits[0].Author);
			Assert.Equal("41a212ee83ca127e3c8cf465891ab7216a705f59", update.Commits[0].Id);
			Assert.Equal("okay i give in", update.Commits[0].Message);
			Assert.Equal(new DateTime(2008, 2, 15, 22, 57, 17, DateTimeKind.Utc), update.Commits[0].Timestamp.ToUniversalTime());
			Assert.Equal("Chris Wanstrath", update.Commits[1].Author);
			Assert.Equal("de8251ff97ee194a289832576287d6f8ad74e3d0", update.Commits[1].Id);
			Assert.Equal("update pricing a tad", update.Commits[1].Message);
			Assert.Equal(new DateTime(2008, 2, 15, 22, 36, 34, DateTimeKind.Utc), update.Commits[1].Timestamp.ToUniversalTime());
		}

	}
}