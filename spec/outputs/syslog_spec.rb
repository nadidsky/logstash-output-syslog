# encoding: utf-8

require "logstash/devutils/rspec/spec_helper"
require "logstash/outputs/syslog"
require "logstash/codecs/plain"
require "json"

describe LogStash::Outputs::Syslog do

  RFC3164_DATE_TIME_REGEX = "(Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec) (0[1-9]|[12][0-9]|3[01]) ([01][0-9]|2[0-3]):([0-5][0-9]):([0-5][0-9]|60)"
  RFC3339_DATE_TIME_REGEX = "([0-9]+)-(0[1-9]|1[012])-(0[1-9]|[12][0-9]|3[01])[Tt]([01][0-9]|2[0-3]):([0-5][0-9]):([0-5][0-9]|60)(\.[0-9]{3})?([Zz]|([+-]([01][0-9]|2[0-3]):[0-5][0-9]))"

  it "should register without errors" do
    plugin = LogStash::Plugin.lookup("output", "syslog").new({"host" => "foo", "port" => "123", "facility" => "kernel", "severity" => "emergency"})
    expect { plugin.register }.to_not raise_error
  end

  subject do
    plugin = LogStash::Plugin.lookup("output", "syslog").new(options)
    plugin.register
    plugin
  end

  let(:socket) { double("fake socket") }
  let(:socket2) { double("fake socket") }
  let(:event) { LogStash::Event.new({"message" => "bar", "host" => "baz"}) }
  let(:sleep_time) {60000}
  let(:events_max_count) { 50000 }


  shared_examples "syslog output" do
    it "should write expected format" do
      expect(subject).to receive(:connect).and_return(socket)
      expect(socket).to receive(:write).with(output)
      subject.receive(event)
    end
  end


  
  shared_examples "syslog output and socket changes by events" do
    it "should write expected format" do
      expect(subject).to receive(:connect).and_return(socket)
      socket=subject.whatsTheSocket
      expect(socket).to receive(:write).with(output)
      subject.receive(event)
    end
    it "should wait for X events to exceed the event threshold" do
      (events_max_count-1).times do |count|
        expect(subject).to receive(:connect).and_return(socket2)
        socket2=subject.whatsTheSocket
        expect(socket2).to receive(:write).with(output)
        expect(socket2).to be(socket)
        subject.receive(event)      
      end
    end
    it "should check whether the socket has changed if we send again an event" do
      expect(subject).to receive(:connect).and_return(socket2)
      expect(socket2).to receive(:write).with(output)
      expect(socket2).not_to be(socket)
      subject.receive(event)      
    end
  end

  
  shared_examples "syslog output and socket changes by time" do
    it "should write expected format" do
      expect(subject).to receive(:connect).and_return(socket)
      expect(socket).to receive(:write).with(output)
      socket=subject.whatsTheSocket
      subject.receive(event)
    end
    it "should wait for X seconds to exceed the timebased threshold" do
      sleep((sleep_time+1000)/1000)
    end
    it "should check whether the socket has changed if we send again an event" do
      expect(subject).to receive(:connect).and_return(socket2)
      socket2=subject.whatsTheSocket
      expect(socket2).to receive(:write).with(output)
      expect(socket2).not_to be(socket)
      subject.receive(event)      
    end
  end

  context "use rebinding 0 by default" do 
    #let(:event) { LogStash::Event.new({"message" => "bar", "host" => "baz", "facility" => "mail", "severity" => "critical", "appname" => "appname", "procid" => "1000" }) }
    let(:options) { {"host" => "foo", "port" => "123", "facility" => "kernel", "severity" => "emergency"} }
    let(:output) { /^<0>#{RFC3164_DATE_TIME_REGEX} baz LOGSTASH\[-\]: bar\n/m }

    it_behaves_like "syslog output"
  end

  context "use rebinding value as 0 defined by the user" do 
#    let(:event) { LogStash::Event.new({"message" => "bar", "host" => "baz", "facility" => "mail", "severity" => "critical", "appname" => "appname", "procid" => "1000" }) }
    let(:options) { {"use_rebinding" => "0","host" => "foo", "port" => "123", "facility" => "kernel", "severity" => "emergency"} }
    let(:output) { /^<0>#{RFC3164_DATE_TIME_REGEX} baz LOGSTASH\[-\]: bar\n/m }
    
    it_behaves_like "syslog output"
  end

  
  context "use rebinding value as 1 and do not pass any other rebind variable" do 
    let(:sleep_time) { 60000 }
#    let(:event) { LogStash::Event.new({"message" => "bar", "host" => "baz", "facility" => "mail", "severity" => "critical", "appname" => "appname", "procid" => "1000" }) }
    let(:options) { {"use_rebinding" => "1","host" => "foo", "port" => "123", "facility" => "kernel", "severity" => "emergency"} }
    let(:output) { /^<0>#{RFC3164_DATE_TIME_REGEX} baz LOGSTASH\[-\]: bar\n/m }
    
    it_behaves_like "syslog output and socket changes by time"
  end  
  context "use rebinding value as 1 and define rebind_interval to one second" do 
    let(:sleep_time) { 1000 }
#    let(:event) { LogStash::Event.new({"message" => "bar", "host" => "baz", "facility" => "mail", "severity" => "critical", "appname" => "appname", "procid" => "1000" }) }
    let(:options) { {"use_rebinding" => "1","rebind_interval" => sleep_time,"host" => "foo", "port" => "123", "facility" => "kernel", "severity" => "emergency"} }
    let(:output) { /^<0>#{RFC3164_DATE_TIME_REGEX} baz LOGSTASH\[-\]: bar\n/m }
    
    it_behaves_like "syslog output and socket changes by time"
  end  
  context "use rebinding value as 2 and not define any of the rebind variables" do 
    let(:sleep_time) { 60000 }
#    let(:event) { LogStash::Event.new({"message" => "bar", "host" => "baz", "facility" => "mail", "severity" => "critical", "appname" => "appname", "procid" => "1000" }) }
    let(:options) { {"use_rebinding" => "1","host" => "foo", "port" => "123", "facility" => "kernel", "severity" => "emergency"} }
    let(:output) { /^<0>#{RFC3164_DATE_TIME_REGEX} baz LOGSTASH\[-\]: bar\n/m }
    
    it_behaves_like "syslog output and socket changes by events"
  end  
  context "use rebinding 2 defined and timebased variable defined to 1 sec" do 
    let(:sleep_time) { 1000 }
    # Should continue with the same connection until it has received 50000 events, ignoring the time
    # in our test should just not change 

#    let(:event) { LogStash::Event.new({"message" => "bar", "host" => "baz", "facility" => "mail", "severity" => "critical", "appname" => "appname", "procid" => "1000" }) }
    let(:options) { {"use_rebinding" => "2","rebind_interval" => sleep_time,"host" => "foo", "port" => "123", "facility" => "kernel", "severity" => "emergency"} }
    let(:output) { /^<0>#{RFC3164_DATE_TIME_REGEX} baz LOGSTASH\[-\]: bar\n/m }
    
    it_behaves_like "syslog output and socket changes by events"
  end  
  
  context "use rebinding 2 defined and rebind_mebased variable defined to 1 sec" do 
    let(:events_max_count) { 1000 }
    # Should continue with the same connection until it has received 50000 events, ignoring the time
    # in our test should just not change 

#    let(:event) { LogStash::Event.new({"message" => "bar", "host" => "baz", "facility" => "mail", "severity" => "critical", "appname" => "appname", "procid" => "1000" }) }
    let(:options) { {"use_rebinding" => "2","rebind_num_messages" => events_max_count,"host" => "foo", "port" => "123", "facility" => "kernel", "severity" => "emergency"} }
    let(:output) { /^<0>#{RFC3164_DATE_TIME_REGEX} baz LOGSTASH\[-\]: bar\n/m }
    
    it_behaves_like "syslog output and socket changes by events"
  end  
  
  context "rfc 3164 and udp by default" do
    let(:options) { {"host" => "foo", "port" => "123", "facility" => "kernel", "severity" => "emergency"} }
    let(:output) { /^<0>#{RFC3164_DATE_TIME_REGEX} baz LOGSTASH\[-\]: bar\n/m }

    it_behaves_like "syslog output"
  end

  context "rfc 5424 and tcp" do
    let(:options) { {"rfc" => "rfc5424", "protocol" => "tcp", "host" => "foo", "port" => "123", "facility" => "kernel", "severity" => "emergency"} }
    let(:output) { /^<0>1 #{RFC3339_DATE_TIME_REGEX} baz LOGSTASH - - - bar\n/m }

    it_behaves_like "syslog output"
  end

  context "calculate priority" do
    let(:options) { {"host" => "foo", "port" => "123", "facility" => "mail", "severity" => "critical"} }
    let(:output) { /^<18>#{RFC3164_DATE_TIME_REGEX} baz LOGSTASH\[-\]: bar\n/m }

    it_behaves_like "syslog output"
  end

  context "sprintf rfc 3164" do
    let(:event) { LogStash::Event.new({"message" => "bar", "host" => "baz", "facility" => "mail", "severity" => "critical", "appname" => "appname", "procid" => "1000" }) }
    let(:options) { {"host" => "foo", "port" => "123", "facility" => "%{facility}", "severity" => "%{severity}", "appname" => "%{appname}", "procid" => "%{procid}"} }
    let(:output) { /^<18>#{RFC3164_DATE_TIME_REGEX} baz appname\[1000\]: bar\n/m }

    it_behaves_like "syslog output"
  end

  context "sprintf rfc 5424" do
    let(:event) { LogStash::Event.new({"message" => "bar", "host" => "baz", "facility" => "mail", "severity" => "critical", "appname" => "appname", "procid" => "1000", "msgid" => "2000" }) }
    let(:options) { {"rfc" => "rfc5424", "host" => "foo", "port" => "123", "facility" => "%{facility}", "severity" => "%{severity}", "appname" => "%{appname}", "procid" => "%{procid}", "msgid" => "%{msgid}"} }
    let(:output) { /^<18>1 #{RFC3339_DATE_TIME_REGEX} baz appname 1000 2000 - bar\n/m }

    it_behaves_like "syslog output"
  end

  context "use_labels == false, default" do
    let(:event) { LogStash::Event.new({"message" => "bar", "host" => "baz" }) }
    let(:options) { {"use_labels" => false, "host" => "foo", "port" => "123" } }
    let(:output) { /^<13>#{RFC3164_DATE_TIME_REGEX} baz LOGSTASH\[-\]: bar\n/m }

    it_behaves_like "syslog output"
  end

  context "use_labels == false, syslog_pri" do
    let(:event) { LogStash::Event.new({"message" => "bar", "host" => "baz", "syslog_pri" => "18" }) }
    let(:options) { {"use_labels" => false, "host" => "foo", "port" => "123" } }
    let(:output) { /^<18>#{RFC3164_DATE_TIME_REGEX} baz LOGSTASH\[-\]: bar\n/m }

    it_behaves_like "syslog output"
  end

  context "use_labels == false, sprintf" do
    let(:event) { LogStash::Event.new({"message" => "bar", "host" => "baz", "priority" => "18" }) }
    let(:options) { {"use_labels" => false, "host" => "foo", "port" => "123", "priority" => "%{priority}" } }
    let(:output) { /^<18>#{RFC3164_DATE_TIME_REGEX} baz LOGSTASH\[-\]: bar\n/m }

    it_behaves_like "syslog output"
  end

  context "use plain codec with format set" do
    let(:plain) { LogStash::Codecs::Plain.new({"format" => "%{host} %{message}"}) }
    let(:options) { {"host" => "foo", "port" => "123", "facility" => "kernel", "severity" => "emergency", "codec" => plain} }
    let(:output) { /^<0>#{RFC3164_DATE_TIME_REGEX} baz LOGSTASH\[-\]: baz bar\n/m }

    it_behaves_like "syslog output"
  end

  context "use codec json" do
    let(:options) { {"host" => "foo", "port" => "123", "facility" => "kernel", "severity" => "emergency", "codec" => "json" } }

    it "should write event encoded with json codec" do
      expect(subject).to receive(:connect).and_return(socket)
      expect(socket).to receive(:write) do |arg|
        message = arg[/^<0>#{RFC3164_DATE_TIME_REGEX} baz LOGSTASH\[-\]: (.*)/, 1]
        expect(message).not_to be_nil
        message_json = JSON.parse(message)
        expect(message_json).to include("@timestamp")
        expect(message_json).to include("host" => "baz")
        expect(message_json).to include("@version" => "1")
        expect(message_json).to include("message" => "bar")
      end
      subject.receive(event)
    end
  end

  context "escape carriage return, newline and newline to \\n" do
    let(:options) { {"host" => "foo", "port" => "123", "facility" => "kernel", "severity" => "emergency", "message" => "foo\r\nbar\nbaz" } }
    let(:output) { /^<0>#{RFC3164_DATE_TIME_REGEX} baz LOGSTASH\[-\]: foo\\nbar\\nbaz\n/m }

    it_behaves_like "syslog output"
  end

  context "tailing newline" do
    let(:options) { {"host" => "foo", "port" => "123", "facility" => "kernel", "severity" => "emergency", "message" => "%{message}\n" } }
    let(:output) { /^<0>#{RFC3164_DATE_TIME_REGEX} baz LOGSTASH\[-\]: bar\n/m }

    it_behaves_like "syslog output"
  end

  context "tailing carriage return and newline (windows)" do
    let(:options) { {"host" => "foo", "port" => "123", "facility" => "kernel", "severity" => "emergency", "message" => "%{message}\n" } }
    let(:output) { /^<0>#{RFC3164_DATE_TIME_REGEX} baz LOGSTASH\[-\]: bar\n/m }

    it_behaves_like "syslog output"
  end
end
