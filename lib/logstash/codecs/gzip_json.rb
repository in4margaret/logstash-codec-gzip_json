# encoding: utf-8
require "logstash/codecs/base"
require "logstash/codecs/plain"
require "logstash/json"
require "zlib"
require 'stringio'

# This codec will read gzip encoded json content
class LogStash::Codecs::GzipJson < LogStash::Codecs::Base
  config_name "gzip_json"


  # The character encoding used in this codec. Examples include "UTF-8" and
  # "CP1252"
  #
  # JSON requires valid UTF-8 strings, but in some cases, software that
  # emits JSON does so in another encoding (nxlog, for example). In
  # weird cases like this, you can set the charset setting to the
  # actual encoding of the text and logstash will convert it for you.
  #
  # For nxlog users, you'll want to set this to "CP1252"
  config :charset, :validate => ::Encoding.name_list, :default => "UTF-8"

  public
  def initialize(params={})
    super(params)
    @converter = LogStash::Util::Charset.new(@charset)
    @converter.logger = @logger
  end

  public
  def decode(data)
    begin
      @decoder = Zlib::GzipReader.new(StringIO.new(data))
      json_string = @decoder.read    
    rescue Zlib::Error, Zlib::GzipFile::Error=> e     
      @logger.error("Gzip codec: We cannot uncompress the gzip file", :error => e, :data => data)
      raise e
    end    

    begin
      yield LogStash::Event.new(JSON.parse(json_string))
    rescue JSON::ParserError => e
      @logger.info('JSON parse failure. Falling back to plain-text', :error => e, :data => json_string)
      yield LogStash::Event.new('message' => json_string)
    end
    
  end # def decode
end # class LogStash::Codecs::GzipJson

