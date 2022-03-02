# frozen_string_literal: true
require "rspec"
require "discorb"
require_relative "../common"

RSpec.describe Discorb::TextChannel do
  let(:channel) do
    Discorb::TextChannel.new(client, JSON.load_file(__dir__ + "/../payloads/channels/text_channel.json", symbolize_names: true))
  end
  it "initializes successfully" do
    expect { channel }.not_to raise_error
  end
  it "posts message" do
    expect_request(
      :post,
      "/channels/863581274916913196/messages",
      body: {
        allowed_mentions: {
          parse: %w[everyone roles users],
          replied_user: nil,
        },
        attachments: [],
        content: "msg",
        tts: false,
      },
    ) do
      {
        code: 200,
        body: File.read("#{__dir__}/../payloads/message.json").then { JSON.parse(_1, symbolize_names: true) },
      }
    end
    expect(channel.post("msg").wait).to be_a Discorb::Message
  end
  context "permissions" do
    it "returns { Discorb::Member, Discorb::Role => Discorb::PermissionOverwrite }" do
      expect(channel.permission_overwrites).to be_a Hash
      expect(channel.permission_overwrites.keys).to all(
        satisfy { |k| k.is_a?(Discorb::Role) || k.is_a?(Discorb::Member) },
      )
      expect(channel.permission_overwrites.values).to all(
        satisfy { |k| k.is_a?(Discorb::PermissionOverwrite) },
      )
    end
  end
  it "creates new invite" do
    expect_request(
      :post,
      "/channels/863581274916913196/invites",
      body: {
        max_age: 0,
        max_uses: 1,
        temporary: false,
        unique: false,
      },
      headers: {
        audit_log_reason: nil,
      },
    ) do
      {
        code: 200,
        body: File.read("#{__dir__}/../payloads/invite.json").then { JSON.parse(_1, symbolize_names: true) },
      }
    end
    expect(channel.create_invite(max_age: 0, max_uses: 1, temporary: false, unique: false).wait).to be_a Discorb::Invite
  end
  it "creates new thread" do
    expect_request(
      :post,
      "/channels/863581274916913196/threads",
      body: {
        auto_archive_duration: 1440,
        name: "thread",
        rate_limit_per_user: nil,
        type: 11,
      },
      headers: {
        audit_log_reason: nil,
      },
    ) do
      {
        code: 200,
        body: File.read("#{__dir__}/../payloads/channels/thread_channel.json").then { JSON.parse(_1, symbolize_names: true) },
      }
    end
    expect(channel.create_thread("thread").wait).to be_a Discorb::ThreadChannel
  end
end
