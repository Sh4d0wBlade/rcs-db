#
# Controller for the Collector objects
#

require 'stringio'

module RCS
module DB

class CollectorController < RESTController
  
  def index
    require_auth_level :server, :sys, :tech

    mongoid_query do
      result = ::Collector.all

      return ok(result)
    end
  end

  def show
    require_auth_level :sys, :tech

    mongoid_query do
      result = Collector.find(@params['_id'])
      return ok(result)
    end
  end

  def create
    require_auth_level :sys

    return conflict('LICENSE_LIMIT_REACHED') unless LicenseManager.instance.check :anonymizers

    result = Collector.create!(name: @params['name']) do |coll|
      coll[:type] = 'remote'
      coll[:address] = @params['address']
      coll[:desc] = @params['desc']
      coll[:port] = @params['port']
      coll[:poll] = @params['poll']
      coll[:configured] = false
      coll[:next] = [nil]
      coll[:prev] = [nil]
    end

    Audit.log :actor => @session[:user][:name], :action => 'collector.create', :desc => "Created the collector '#{@params['name']}'"

    return ok(result)
  end

  def update
    require_auth_level :sys

    mongoid_query do
      coll = Collector.find(@params['_id'])
      @params.delete('_id')

      @params.each_pair do |key, value|
        if coll[key.to_s] != value and not key['_ids']
          Audit.log :actor => @session[:user][:name], :action => 'collector.update', :desc => "Updated '#{key}' to '#{value}' for collector '#{coll['name']}'"
        end
      end

      coll.update_attributes(@params)
      
      return ok(coll)
    end
  end
  
  def destroy
    require_auth_level :sys

    mongoid_query do
      collector = Collector.find(@params['_id'])

      Audit.log :actor => @session[:user][:name], :action => 'collector.destroy', :desc => "Deleted the collector '#{collector[:name]}'"

      collector.destroy
      return ok
    end    
  end

  def version
    require_auth_level :server

    mongoid_query do
      collector = Collector.find(@params['_id'])
      @params.delete('_id')
      
      collector.version = @params['version']
      collector.save
      
      return ok
    end
  end

  def config
    require_auth_level :server, :admin

    mongoid_query do
      collector = Collector.find(@params['_id'])

      return not_found if collector.configured

      # get the next hop collector
      next_hop = Collector.find(collector.prev[0])

      #Zip::ZipFile.open(Config.instance.temp(collector._id.to_s), Zip::ZipFile::CREATE) do |z|
      #  z.file.open('etc/nexthop', "w") { |f| f.write next_hop.address }
      #end

      # create the tar.gz with the config
      gz = Zlib::GzipWriter.new(File.open(Config.instance.temp(collector._id.to_s), 'wb'))
      output = Minitar::Output.new(gz)
      nexthop = StringIO.new(next_hop.address)
      Minitar::pack_stream('etc/nexthop', nexthop, output)
      output.close

      # reset the flag for the "configuration needed"
      collector.configured = true
      collector.save

      return stream_file(Config.instance.temp(collector._id.to_s), proc { FileUtils.rm_rf Config.instance.temp(collector._id.to_s) })
    end
  end

  def log
    mongoid_query do
      collector = Collector.find(@params['_id'])

      case @request[:method]
        when 'GET'
          require_auth_level :sys

          klass = CappedLog.collection_class collector[:_id]
          logs = klass.all
          return ok(logs)

        when 'POST'
          require_auth_level :server

          entry = CappedLog.dynamic_new collector[:_id]
          entry.time = Time.parse(@params['time']).getutc.to_i
          entry.type = @params['type'].downcase
          entry.desc = @params['desc']
          entry.save
          return ok
      end

      return bad_request
    end
  end

  def del_logs
    require_auth_level :sys

    mongoid_query do
      collector = Collector.find(@params['_id'])

      # we cannot call delete_all on a capped collection
      # we must drop it:
      # http://www.mongodb.org/display/DOCS/Capped+Collections#CappedCollections-UsageandRestrictions
      db = Mongoid.database
      logs = db.collection(CappedLog.collection_name(collector[:_id]))
      logs.drop

      return ok
    end
  end

end

end #DB::
end #RCS::
