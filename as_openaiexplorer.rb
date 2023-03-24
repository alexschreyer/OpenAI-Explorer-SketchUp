=begin

Copyright 2023, Alexander C. Schreyer
All rights reserved

THIS SOFTWARE IS PROVIDED "AS IS" AND WITHOUT ANY EXPRESS OR IMPLIED WARRANTIES,
INCLUDING, WITHOUT LIMITATION, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND
FITNESS FOR A PARTICULAR PURPOSE.

License:        GPL (http://www.gnu.org/licenses/gpl.html)

Author :        Alexander Schreyer, www.alexschreyer.net, mail@alexschreyer.net

Website:        https://alexschreyer.net/projects/openai-explorer-experimental/

Name :          OpenAIExplorer (Experimental)

Version:        1.0.1

Date :          3/24/2023

Description :   An experimental extension to use OpenAI’s services to create or manipulate geometry in SketchUp using natural language.

History:        1.0 (3/18/2023):
                - first version
                1.0.1 (3/24/2023):
                - Added cleanup for the returned code/text
                - Added error handling for API and a one-time warning for the extension
                

=end


# ========================


require 'sketchup.rb'
require 'extensions.rb'


# ========================


module AS_Extensions

  module AS_OpenAIExplorer
  
    @extversion           = "1.0.1"
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
