module Intrigue
module Task
module Enrich
class SnmpService < Intrigue::Task::BaseTask

  def self.metadata
    {
      :name => "enrich/snmp_service",
      :pretty_name => "Enrich SnmpService",
      :authors => ["jcran"],
      :description => "Enrich an SNMP service",
      :references => [],
      :type => "enrichment",
      :passive => false,
      :allowed_types => ["SnmpService"],
      :example_entities => [
        { "type" => "SnmpService",
          "details" => {
            "ip_address" => "1.1.1.1",
            "port" => 161,
            "protocol" => "udp"
          }
        }
      ],
      :allowed_options => [],
      :created_types => []
    }
  end

  ## Default method, subclasses must override this
  def run
    _log "Enriching... SNMP service: #{_get_entity_name}"

    port = _get_entity_detail("port").to_i || 161
    ip_address = _get_entity_detail "ip_address"

    # Create a tempfile to store results
    temp_file = "#{Dir::tmpdir}/nmap_snmp_info_#{rand(100000000)}.xml"

    nmap_string = "nmap #{ip_address} -sU -p #{port} --script=snmp-info -oX #{temp_file}"
    nmap_string = "sudo #{nmap_string}" unless Process.uid == 0

    _log "Running... #{nmap_string}"
    nmap_output = _unsafe_system nmap_string

    # parse the file and get output, setting it in details
    doc = File.open(temp_file) { |f| Nokogiri::XML(f) }

    service_doc = doc.xpath("//service")
    begin
      if service_doc && service_doc.attr("product")
        snmp_product = service_doc.attr("product").text
      end
    rescue NoMethodError => e
      _log_error "Unable to find attribute: product"
    end

    begin
      script_doc = doc.xpath("//script")
      if script_doc && script_doc.attr("output")
        script_output = script_doc.attr("output").text
      end
    rescue NoMethodError => e
      _log_error "Unable to find attribute: output"
    end


    _log "Got SNMP details:#{script_output}"

    _set_entity_detail("product", snmp_product)
    _set_entity_detail("script_output", script_output)

    # cleanup
    begin
      File.delete(temp_file)
    rescue Errno::EPERM
      _log_error "Unable to delete file"
    end
  end

end
end
end
end