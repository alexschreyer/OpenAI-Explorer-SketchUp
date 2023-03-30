=begin

Copyright 2023, Alexander C. Schreyer
All rights reserved

THIS SOFTWARE IS PROVIDED 'AS IS' AND WITHOUT ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, WITHOUT LIMITATION, THE IMPLIED WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE, AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHOR OR ANY COPYRIGHT HOLDER BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY ARISING FROM, OUT OF OR IN CONNECTION WITH THIS SOFTWARE OR THE USE OR OTHER DEALINGS IN THIS SOFTWARE.

WHERE APPLICABLE, THIRD-PARTY MATERIALS AND THIRD-PARTY PLATFORMS ARE PROVIDED 'AS IS' AND THE USER OF THIS SOFTWARE ASSUMES ALL RISK AND LIABILITY REGARDING ANY USE OF (OR RESULTS OBTAINED THROUGH) THIRD-PARTY MATERIALS OR THIRD-PARTY PLATFORMS.

License:        GPL (https://www.gnu.org/licenses/gpl-3.0.html)

Author :        Alexander Schreyer, www.alexschreyer.net, mail@alexschreyer.net

Website:        https://alexschreyer.net/projects/openai-explorer-experimental/

Name :          OpenAIExplorer (Experimental)

Version:        1.0.2

Date :          3/28/2023

Description :   An experimental extension to use OpenAI’s services to create or manipulate geometry in SketchUp using natural language.

History:        1.0 (3/18/2023):
                - first version
                1.0.1 (3/24/2023):
                - Added cleanup for the returned code/text
                - Added error handling for API and a one-time warning for the extension
                1.0.2 (3/28/2023):
                - Fixed error handling bug
                - Added a double-check for delete requests
                1.0.3 (TBD)
                - Added license/disclaimer file
                - Added better license display on first use
                - Added link to OpenAI TOU to menu
                - Reverted the prompt prefix to a text box
                - Disabled code execution as the default

=end


# ========================


require 'sketchup.rb'
require 'extensions.rb'


# ========================


module AS_Extensions

  module AS_OpenAIExplorer
  
    @extversion           = "1.0.2"
    @exttitle             = "OpenAI Explorer (Experimental)"
    @extname              = "as_openaiexplorer"
    
    @extdir = File.dirname(__FILE__)
    @extdir.force_encoding('UTF-8') if @extdir.respond_to?(:force_encoding)
    
    loader = File.join( @extdir , @extname , "as_openaiexplorer.rb" )
   
    extension             = SketchupExtension.new( @exttitle , loader )
    extension.copyright   = "Copyright 2023-#{Time.now.year} Alexander C. Schreyer"
    extension.creator     = "Alexander C. Schreyer, www.alexschreyer.net"
    extension.version     = @extversion
    extension.description = "An experimental tool to query the OpenAI API using natural language and then execute the resulting code in SketchUp (to create or manipulate geometry)."
    
    Sketchup.register_extension( extension , true )
         
  end  # module AS_OpenAIExplorer
  
end  # module AS_Extensions


# ========================
