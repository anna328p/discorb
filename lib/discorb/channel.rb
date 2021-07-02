# frozen_string_literal: true

require 'time'
require_relative 'flag'
require_relative 'common'

module Discorb
  class Channel < DiscordModel
    attr_reader :id, :name, :channel_type

    @channel_type = nil
    @subclasses = []

    def initialize(client, data)
      @client = client
      _set_data(data)
    end

    def ==(other)
      @id == other.id
    end

    def inspect
      "#<#{self.class} \"##{@name}\" id=#{@id}>"
    end

    def self.inherited(subclass)
      @subclasses = [] if @subclasses.nil?
      @subclasses << subclass
    end

    def self.make_channel(client, data)
      @subclasses.each do |klass|
        return klass.new(client, data) if !klass.channel_type.nil? && klass.channel_type == data[:type]
      end
    end

    class << self
      attr_reader :channel_type
    end

    def type
      self.class.channel_type
    end

    private

    def _set_data(data)
      @id = Snowflake.new(data[:id])
      @name = name
      @guild_id = data[:guild_id]
      @client.channels[@id] = self
    end
  end

  class GuildChannel < Channel
    attr_reader :position, :permission_overwrites

    include Comparable
    @channel_type = nil

    def <=>(other)
      @position <=> other.position
    end

    def parent
      return nil unless @parent_id

      @client.channels[@parent_id]
    end

    alias category parent

    def guild
      @client.guilds[@guild]
    end

    def inspect
      "#<#{self.class} \"##{@name}\" id=#{@id}>"
    end

    private

    def _set_data(data)
      @guild_id = data[:guild_id]
      @position = data[:position]
      @permission_overwrites = nil # TODO: Hash<Discorb::PermissionOverwrite>
      @parent_id = data[:parent_id]
      super
    end
  end

  class TextChannel < GuildChannel
    attr_reader :topic, :nsfw, :last_message_id, :rate_limit_per_user, :last_pin_timestamp

    @channel_type = 0

    alias slowmode rate_limit_per_user

    def post(content = nil, tts: false, embed: nil, embeds: nil, allowed_mentions: nil, message_reference: nil, components: nil)
      Async do |_task|
        payload = {}
        payload[:content] = content if content
        payload[:tts] = tts
        tmp_embed = if embed
                      [embed]
                    elsif embeds
                      embeds
                    end
        payload[:embeds] = tmp_embed.map(&:to_hash) if tmp_embed
        payload[:allowed_mentions] =
          allowed_mentions ? allowed_mentions.to_hash(@client.allowed_mentions) : @client.allowed_mentions.to_hash
        payload[:message_reference] = message_reference.to_reference if message_reference
        if components
          tmp_components = if components.filter { |c| c.is_a? Array }.length.zero?
                             [components].map { |c| c }
                           else
                             components.map { |c| c.is_a?(Array) ? c : [c] }
                           end
          payload[:components] = tmp_components.map { |c| { type: 1, components: c.map(&:to_hash) } }
        end
        Message.new(@client, @client.internet.post("/channels/#{id}/messages", payload).wait[1])
      end
    end

    def edit(name: nil, announce: nil, position: nil, topic: nil, nsfw: nil, slowmode: nil, category: nil, parent: nil)
      Async do
        payload = {}
        payload[:name] = name if name
        payload[:announce] = announce ? 5 : 0 unless announce.nil?
        payload[:position] = position if position
        payload[:topic] = topic || '' unless topic.nil?
        payload[:nsfw] = nsfw unless nsfw.nil?

        payload[:rate_limit_per_user] = slowmode || 0 unless slowmode.nil?
        parent ||= category
        payload[:parent_id] = parent.id unless parent.nil?

        @client.internet.patch("/channels/#{@id}", payload)
      end
    end

    private

    def _set_data(data)
      @topic = data[:topic]
      @nsfw = data[:nsfw]
      @last_message_id = data[:last_message_id]
      @rate_limit_per_user = data[:rate_limit_per_user]
      @last_pin_timestamp = data[:last_pin_timestamp] ? Time.iso8601(data[:last_pin_timestamp]) : nil
      super
    end
  end

  class VoiceChannel < GuildChannel
    attr_reader :bitrate, :user_limit

    @channel_type = 2
    def edit(name: nil, position: nil, bitrate: nil, user_limit: nil)
      Async do
        payload = {}
        payload[:name] = name if name
        payload[:position] = position if position
        payload[:bitrate] = bitrate unless bitrate.nil?
        payload[:user_limit] = user_limit unless user_limit.nil?

        @client.internet.patch("/channels/#{@id}", payload)
      end
    end

    private

    def _set_data(data)
      @bitrate = data[:bitrate]
      @user_limit = data[:user_limit]
      super
    end
  end

  class ThreadChannel < DiscordModel
    attr_reader :id, :name, :type, :message_count, :member_count, :rate_limit_per_user

    alias slowmode rate_limit_per_user
    @channel_type = nil

    def initialize(client, data)
      @client = client
      _set_data(data)
    end

    def ==(other)
      @id == other.id
    end

    def parent
      return nil unless @parent_id

      @client.channels[@parent_id]
    end

    alias channel parent

    def guild
      @client.guilds[@guild]
    end

    def owner
      guild.members[@owner_id]
    end

    def inspect
      "#<#{self.class} \"##{@name}\" id=#{@id}>"
    end

    class << self
      attr_reader :channel_type
    end

    private

    def _set_data(data)
      @id = Snowflake.new(data[:id])
      @name = name
      @guild_id = data[:guild_id]
      @parent_id = data[:parent_id]
      @client.channels[@parent_id]&.threads&.push(self) unless @parent_id.nil?

      @client.channels[@id] = self
    end
  end

  class PublicThreadChannel < GuildChannel
    attr_reader :bitrate, :user_limit

    @channel_type = 11
    def edit(name: nil, position: nil, bitrate: nil, user_limit: nil)
      Async do
        payload = {}
        payload[:name] = name if name
        payload[:position] = position if position
        payload[:bitrate] = bitrate unless bitrate.nil?
        payload[:user_limit] = user_limit unless user_limit.nil?

        @client.internet.patch("/channels/#{@id}", payload)
      end
    end

    private

    def _set_data(data)
      @bitrate = data[:bitrate]
      @user_limit = data[:user_limit]
      super
    end
  end

  class PrivateThreadChannel < GuildChannel
    attr_reader :bitrate, :user_limit

    @channel_type = 12
    def edit(name: nil, position: nil, bitrate: nil, user_limit: nil)
      Async do
        payload = {}
        payload[:name] = name if name
        payload[:position] = position if position
        payload[:bitrate] = bitrate unless bitrate.nil?
        payload[:user_limit] = user_limit unless user_limit.nil?

        @client.internet.patch("/channels/#{@id}", payload)
      end
    end

    private

    def _set_data(data)
      @bitrate = data[:bitrate]
      @user_limit = data[:user_limit]
      super
    end
  end

  class CategoryChannel < GuildChannel
    attr_reader :channels

    @channel_type = 4
    def text_channels
      @channels.filter { |c| c.is_a? TextChannel }
    end

    def voice_channels
      @channels.filter { |c| c.is_a? VoiceChannel }
    end

    private

    def _set_data
      super
      @channels = @client.channels.value.filter { |channel| channel.parent == self }
    end
  end
end
