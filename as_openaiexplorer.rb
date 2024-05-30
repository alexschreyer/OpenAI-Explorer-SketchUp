=begin

Copyright 2023-2024, Alexander C. Schreyer
All rights reserved

THIS SOFTWARE IS PROVIDED 'AS IS' AND WITHOUT ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, WITHOUT LIMITATION, THE IMPLIED WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE, AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHOR OR ANY COPYRIGHT HOLDER BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY ARISING FROM, OUT OF OR IN CONNECTION WITH THIS SOFTWARE OR THE USE OR OTHER DEALINGS IN THIS SOFTWARE.

WHERE APPLICABLE, THIRD-PARTY MATERIALS AND THIRD-PARTY PLATFORMS ARE PROVIDED 'AS IS' AND THE USER OF THIS SOFTWARE ASSUMES ALL RISK AND LIABILITY REGARDING ANY USE OF (OR RESULTS OBTAINED THROUGH) THIRD-PARTY MATERIALS OR THIRD-PARTY PLATFORMS.

License:        GPL (https://www.gnu.org/licenses/gpl-3.0.html)

Author :        Alexander Schreyer, www.alexschreyer.net, mail@alexschreyer.net

Website:        https://alexschreyer.net/projects/openai-explorer-experimental/

Name :          OpenAIExplorer (Experimental)

Version:        2.3

Date :          5/18/2024

Description :   An experimental extension to use OpenAI’s services to create or manipulate geometry in SketchUp using natural language.

History:        1.0 (3/18/2023):
                - first version
                1.0.1 (3/24/2023):
                - Added cleanup for the returned code/text
                - Added error handling for API and a one-time warning for the extension
                1.0.2 (3/28/2023):
                - Fixed error handling bug
                - Added a double-check for delete requests
                1.0.3 (7/19/2023):
                - Added license/disclaimer file
                - Added better license display on first use
                - Added link to OpenAI TOU to menu
                - Reverted the prompt prefix to a text box (user can now enter anything)
                - Disabled code execution as the default (can be turned on in settings)
                - Changed from OpenAI completion model to chat model (OpenAI changes), see:
                  https://openai.com/blog/gpt-4-api-general-availability
                2.0 (7/23/2023):
                - Created dialog-based input for more chat-like experience
                - Moved error reporting into dialog to reduce pop-ups
                2.1 (9/23/2023):
                - Better error handling
                - Fixed gpt-4 markdown extraction issue
                - Added a timer
                - Set a 30 seconds read timeout for hung requests
                2.2 (12/9/2023):
                - Implemented correct system message handling as per OpenAI API
                - Added system message to prevent file access when code is to be executed
                - Updated default system message
                - Added menu item to reset extension settings (for troubleshooting)
                2.3 (5/18/2024):
                - Updated some defaults
                - Updated button design
                - Added AI "memory". User can now select how many messages get sent to OpenAI.                
                - Added screenshot image upload for vision-capable models (e.g. gpt-4o)
                - Added resolution control for uploaded images
                2.4 ():
                - Now renders bold text and code visually in responses
                - Better response handling
                - Dialog now always opens centered
                

=end


# ========================


require 'sketchup.rb'
require 'extensions.rb'


# ========================


module AS_Extensions

  module AS_OpenAIExplorer
  
    @extversion           = "2.3"
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
