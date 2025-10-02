# ==================
# Main file for OpenAiExplorer
# ==================


require 'sketchup'
require 'net/http'
require 'uri'
require 'json'
require 'base64'
require 'stringio'


# ==================


module AS_Extensions

  module AS_OpenAIExplorer  

    # Set up some module-wide defaults as a hash
    @default_settings_hash = {
      "systemMessage" => "Respond within the context of SketchUp.",  # System Message
      "aiModel" => "gpt-4.1-mini",  # Chat Completion Model
      "maxTokens" => "1024",  # Max. Tokens
      "temperature" => "0.1",  # Temperature
      "apiKey" => "",  # OpenAI/Google/... API key
      "executeCode" => false,  # Execute code
      "submitModelView" => false,  # Submit model view with request
      "modelViewQuality" => "low",  # Model view submission quality
      "numPrompts" => "3",  # Number of submitted messages (user and assistant)
      "aiEndpoint" => "https://api.openai.com/v1/chat/completions",  # Service provider endpoint
      "colorMode" => "dark",  # Color mode
      "useCase" => "chat",  # Use case
      "useFunctionCalling" => false,  # Use function calling - Not used at this point
      "functionCallingJson" => "[]"  # Function calling JSON
    }
    
    # Create an empty array for all AI messages
    @ai_messages = []    

    # Placeholder for file attachment
    @ai_attachment = ""  

    # Load all the system messages from a JSON file
    @system_msgs = {}
    file_path = File.join(__dir__, 'system_msgs.json')
    begin
      # Read and parse the JSON file
      file_content = File.read(file_path)
      @system_msgs = JSON.parse(file_content)

      # Ensure the parsed content is a hash
      unless @system_msgs.is_a?(Hash)
        raise "Invalid JSON format."
      end

      # puts "System messages loaded successfully from #{file_path}."
    rescue Errno::ENOENT
      puts "Error: File not found at #{file_path}."
    rescue JSON::ParserError => e
      puts "Error parsing JSON file: #{e.message}"
    rescue StandardError => e
      puts "An error occurred: #{e.message}"
    end
  
  
    # ==================
    
    
    def self.encoded_screenshot
    # Saves and encodes the current model view in Base64 format
    
        # Save the current model view to a temp location
        dir = (defined? Sketchup.temp_dir) ? Sketchup.temp_dir : ENV['TMPDIR'] || ENV['TMP'] || ENV['TEMP']
        file_loc = File.join( dir, "temp.png" )
        keys = {
            :filename => file_loc,
            :antialias => true,
            :scale_factor => 1,
            :compression => 0.8,
            :transparent => false
        }
        img = Sketchup.active_model.active_view.write_image keys
        
        # Encode the file as Base64
        base64_image = File.open(file_loc, "rb") do |file|
            Base64.strict_encode64(file.read)
        end
        
        return base64_image
    
    end # encoded_screenshot    
    
    
    # ==================        


    def self.encoded_file(file_path)
    # Encodes a file in Base64 format
        
        # Encode the file as Base64
        base64_file = File.open(file_path, "rb") do |file|
            Base64.strict_encode64(file.read)
        end
        
        return base64_file
    
    end # encoded_file    
    
    
    # ==================            
    
    
    def self.show_disclaimer_window
    # Shows a license and disclaimer window
        
        # Show a window with my terms of use
        f = File.join( __dir__ , "license.txt" )
        dlg_f = File.join( __dir__ , "license_dlg.html" )
        disclaimer = File.read(f)
        title = @exttitle + " | Readme & Terms of Use"
        
        dlg = UI::HtmlDialog.new( { :dialog_title => title, :width => 600, :height => 700, top: 100, left: 100,
          :style => UI::HtmlDialog::STYLE_UTILITY, :preferences_key => title.gsub(/\s+/, "_") } )
        dlg.set_file( dlg_f )
                
        dlg.add_action_callback("license_accepted") do |action_context|
          Sketchup.write_default( @extname , "disclaimer_acknowledged" , "yes" )
          dlg.close
        end  
        
        dlg.add_action_callback("load_license") do |action_context|        
          js = "document.getElementById('tou-text').textContent = " + disclaimer.dump
          dlg.execute_script(js)   
        end     
        
        dlg.show_modal
        dlg.center    

    end # show_disclaimer_window


    # ================== 

    
    def self.openai_explorer_dialog
    # Opens a connection to the OpenAI API and executes what comes back - uses HTML dialog
    
        toolname = @exttitle
        
        # Show disclaimer once
        default = Sketchup.read_default( @extname , "disclaimer_acknowledged" )        
        if default.to_s != "yes" then 
            self.show_disclaimer_window 
            Sketchup.write_default( @extname , "disclaimer_acknowledged" , "yes" )
        end       
        
        # Get the settings, including the API key
        settings = Sketchup.read_default( @extname , "ai_explorer_settings_hash" , @default_settings_hash )     

        # Set up the dialog
        @dialog = UI::HtmlDialog.new(
            dialog_title: toolname,
            preferences_key: @extname,
            scrollable: true,
            resizable: true,
            top: 100,
            left: 100,
            width: 400,
            height: 600,
            min_width: 300,
            min_height: 400,
            style: UI::HtmlDialog::STYLE_DIALOG
        )
        @dialog.set_file(File.join(@extdir,@extname,'as_openaiexplorer_ui.html'))
        @dialog.show
        @dialog.center
        
        # Callback to close dialog
        @dialog.add_action_callback("close_dlg") { |action_context|
            # Save the settings to SketchUp
            js = "write_settings();"
            @dialog.execute_script(js)
            @dialog.close
        }
        
        # Callback to show disclaimer dialog
        @dialog.add_action_callback("disclaimer_dlg") { |action_context|
            self.show_disclaimer_window
        }  
        
        # Callback to show help dialog
        @dialog.add_action_callback("help_dlg") { |action_context|
            self.show_help
        }

        # Callback to clear dialog
        @dialog.add_action_callback("clear_dlg") { |action_context|
            @ai_messages.clear
            @ai_attachment = ""
            js = "jQuery('#attachFile').attr('title','Attach a file').removeClass('active');"
            @dialog.execute_script(js)   
        }             
        
        # Callback to send settings to dialog
        @dialog.add_action_callback("read_settings") { |action_context|
            # Get the current settings
            settings = Sketchup.read_default( @extname , "ai_explorer_settings_hash" , @default_settings_hash )
            js = "apply_settings(#{settings.to_json})"
            @dialog.execute_script(js)                  
        }      

        # Callback to save settings from dialog
        @dialog.add_action_callback("write_settings") { |action_context,settings|
            Sketchup.write_default( @extname , "ai_explorer_settings_hash" , settings )
        }        
        
        # Callback to send system messages to dialog
        @dialog.add_action_callback("get_system_msgs") { |action_context| 
            js = "const systemMsgs = #{@system_msgs.to_json};"
            @dialog.execute_script(js)                  
        }     

        # Callback to get filename for attachment
        @dialog.add_action_callback("get_file") { |action_context| 
            f = UI.openpanel("Select a PDF or Ruby file to attach to your prompt", "", "PDF Files;Ruby files|*.pdf;*.rb||")
            if !(f.nil? || f.empty?)
                @ai_attachment = f.to_s.gsub("\\", "/")
                fname = File.basename(f)
                js = "jQuery('#attachFile').attr('title','#{fname}');"
                @dialog.execute_script(js)   
            else
                @ai_attachment = ""
                js = "jQuery('#attachFile').attr('title','Attach a file').removeClass('active');"
                @dialog.execute_script(js)   
            end            
        }               
        
        # Callback to submit prompt and get response
        @dialog.add_action_callback("submit_prompt") { |action_context,ui_prompt|

            begin

                mod = Sketchup.active_model # Currently open model
                
                # Get the settings - in case anything changed
                js = "write_settings();"
                @dialog.execute_script(js)
                settings = Sketchup.read_default( @extname , "ai_explorer_settings_hash" , @default_settings_hash )        

                # Start a timer
                t1 = Time.now

                # Start a new undo group
                mod.start_operation("AI Experiment")
                
                # Reset this variable
                ruby_result = ''

                # Life is always better with some feedback while SketchUp works
                Sketchup.status_text = toolname + " | Starting request"
                info = ""

                # Set the endpoint and API key for the OpenAI/Google/... API
                unless settings["aiEndpoint"].to_s.include?('https://')
                  raise "AI API endpoint does not look like a valid URL. Please correct before trying again."
                end
                endpoint = settings["aiEndpoint"].to_s
                api_key = settings["apiKey"].to_s

                # Define the prompt for the code completion
                prompt = ui_prompt.to_s
                sys_prompt = settings["systemMessage"].to_s
                sys_prompt += " Do not generate any Ruby code that operates on the local computer's file system." if ( settings["executeCode"] == true )
                sys_prompt += " Format your response with HTML tags for the BODY section of a page (but exclude the BODY tag). Enclose any Ruby code in <pre> tags."

                # Add raw data to console output
                puts "\n#{@exttitle} - RAW OUTPUT:\n"
                puts "\nPrompt ============\n(System:) #{sys_prompt}\n(User:) #{prompt}"
                
                # Set up user mesage (only prompt, no image)
                user_message = {  
                                  "role" => "user", 
                                  "content" => [
                                    { "type" => "text", "text" => "#{prompt}" }
                                  ] 
                                }
                
                # Modify user mesage if we want to include the model view
                if ( settings["submitModelView"] == true ) 
                    base64_image = encoded_screenshot;
                    user_message["content"].push(
                            {   "type" => "image_url", 
                                "image_url" => 
                                { "url" => "data:image/png;base64,#{base64_image}", 
                                  "detail" => "#{settings["modelViewQuality"]}" } 
                            })
                          
                    prompt = prompt + "<br /><img src='data:image/png;base64,#{base64_image}' class='thumbnail' title='Submitted view' />"
                end

                # Modify user message if we have an attachment
                if ( @ai_attachment != "" )
                    ext = File.extname(@ai_attachment)
                    if ext.downcase == ".pdf"                    
                        # Encode the file as Base64 
                        base64_file = encoded_file(@ai_attachment)
                        filename = File.basename(@ai_attachment)  
                        user_message["content"].push(
                                {   "type" => "file", 
                                    "file" =>  
                                    { "filename" => "#{filename}", 
                                      "file_data" => "data:application/pdf;base64,#{base64_file}" }  
                                })
                    elsif ext.downcase == ".rb"
                        rb_text = File.read(@ai_attachment)
                        user_message["content"][0]["text"] += "\n\nConsider this Ruby code in your answer: ```ruby#{rb_text}```"  
                    end
                    # Add the attachment to the prompt
                    prompt = prompt + "<br /><p class='file_ref'><i class='fas fa-paperclip'></i> #{@ai_attachment}</p>"
                end

                # Add function calling JSON if desired
                if settings["useFunctionCalling"] == true && settings["functionCallingJson"].to_s.strip != ""
                  begin
                    function_json = JSON.parse(settings["functionCallingJson"].to_s)
                  rescue JSON::ParserError => e
                    puts "Error parsing function calling JSON: #{e.message}"
                    function_json = nil
                  end
                else
                  function_json = nil
                end
                
                js = "add_prompt(#{prompt.dump})"
                @dialog.execute_script(js)
                
                # Add the request to the array of messages
                @ai_messages.push( user_message )

                # Set up the HTTP request with the API key and prompt
                uri = URI(endpoint)
                req = Net::HTTP::Post.new(uri)
                req["Content-Type"] = "application/json"
                req["Authorization"] = "Bearer #{api_key}"

                body_hash = {
                  "model" => settings["aiModel"].to_s,
                  "messages" => [{ "role" => "system", "content" => "#{sys_prompt}" }] + @ai_messages.last( settings["numPrompts"].to_i ),
                  "max_completion_tokens" => settings["maxTokens"].to_i,
                  # "top_p" => 1,
                  "n" => 1,
                  "temperature" => settings["temperature"].to_f,
                  "stream" => false
                  # "stop" => "\n"
                }

                # Only add the tool code if executeCode is true
                body_hash["tools"] = function_json if ( function_json and settings["executeCode"] )

                req.body = JSON.dump(body_hash)

                # Make the HTTP request to the OpenAI/Google/... API and parse the response
                res = Net::HTTP.start(uri.hostname, uri.port, use_ssl: true, read_timeout: 30) do |http|
                  http.request(req)
                end
                response_body = JSON.parse(res.body)
                
                # Add raw response to console output
                puts "\nRaw Request ============\n"
                puts req.body
                puts "\nRaw Response ============\n"
                puts response_body
                
                # Add the response to the array of messages
                @ai_messages.push( response_body["choices"][0]["message"] )

                # Get the generated response from the API response and add it to the console
                generated_response = response_body["choices"][0]["message"]["content"]          
                puts "\nResult ============\n"
                puts generated_response

                # Display some statistics in the Ruby console
                info += "Tokens used: " + response_body["usage"]["total_tokens"].to_s                    
                puts "\nStats ============\n"
                puts info     
                puts "Finish reason: " + response_body["choices"][0]["finish_reason"].to_s    

                # Double-check for a destructive request
                badwords = ['delete','remove','erase','kill','expunge']
                isbad = badwords.any? { |w| prompt.downcase.include? w }
                if ( settings["executeCode"] == true && isbad ) then             
                    delete_check = UI.messagebox "You seem to be asking to delete something. Are you sure you want to execute the generated code?", MB_YESNO
                else           
                    delete_check = 6
                end

                # Execute code only when desired
                if ( settings["executeCode"] == true && delete_check == 6 )

                    # Life is always better with some feedback while SketchUp works
                    Sketchup.status_text = toolname + " | Executing code"                           

                    # Extract the generated code
                    if generated_response.include? "```ruby"     # For quoted code
                        generated_code = generated_response[/```ruby(.*?)```/m, 1]
                        generated_code.gsub!(/<[^>]+?>/,'')  # Strip HTML tags (with attributes)
                        info += " | Code was executed."
                    elsif generated_response.include? "<pre>"     # For HTML tags
                        generated_code = generated_response[/\<pre\>(.*?)\<\/pre\>/m, 1]
                        generated_code.gsub!(/<[^>]+?>/,'')  # Strip HTML tags (with attributes)
                        info += " | Code was executed."
                    else
                        generated_code = ''
                        info += " | No usable code in the response."
                    end

                    # Display the generated response in the Ruby console
                    # if generated_code != ''
                    #     puts "\nExecuted Code ============\n"
                    #     puts generated_code   
                    # end                 
                    
                    # Execute it and capture any output
                    old_stdout = $stdout
                    $stdout = StringIO.new
                    
                    ruby_result = eval( generated_code, TOPLEVEL_BINDING )
                    
                    ruby_result = $stdout.string
                    $stdout = old_stdout

                else

                    nocode = "No code was executed."
                    info += " | " + nocode
                    puts nocode

                end      

                # Life is always better with some feedback while SketchUp works
                Sketchup.status_text = toolname + " | Done"     

                # Finish a new undo group
                mod.commit_operation

              rescue Exception => e    
              
                errmsg = ""
                  
                # Provide an error message for OpenAI/Google errors if they get returned
                if ( defined?(response_body['error']['message']) != nil ) then
                    errmsg += "<b>(AI Service:)</b> #{response_body['error']['message']} "
                end                     

                # Provide an error message for SketchUp errors
                errmsg += "<b>(SketchUp:)</b> #{e}. "

                puts "This request generated an error. See dialog for details.\n"        
                
                # Reset the output in any case
                $stdout = old_stdout if old_stdout

            end    
            
            # Measure duration
            duration = Time.now - t1
            info += " | Time elapsed: %0.2fs" % duration     
            
            # Did we get an error?
            info += " | <span class='error'><strong>ERROR:</strong> " + errmsg + "</span>" if errmsg != nil

            # Display result and stats in the dialog
            if generated_response!=nil
            
                # Clean up output:

                # Remove any enclosing HTML code markdown - need for Gemini
                if generated_response.include? "```html"
                  generated_response = generated_response[/```html(.*?)```/m, 1]
                end

                # Replace code tags first
                generated_response.gsub!( /\`\`\`[^\s]+/, "<pre>" )
                generated_response.gsub!( /\`\`\`/, "</pre>" )

                # Protect code content and then replace all other tags
                # Not elegant but it'll do
                code_blocks = []
                generated_response.gsub!(/<pre>(.*?)<\/pre>/m) do |match|
                  code_blocks << match
                  'ASDASDASDASDASDASDASDASD'
                end

                generated_response.gsub!( /\*\*(.*?)\*\*/ ) { "<b>#{$1}</b>" }
                generated_response.gsub!( /\*(.*?)\*/ ) { "<i>#{$1}</i>" }
                generated_response.gsub!( /####\s(.*)?\n/ ) { "<h4>#{$1}</h4>" }
                generated_response.gsub!( /###\s(.*)?\n/ ) { "<h3>#{$1}</h3>" } 
                generated_response.gsub!( /##\s(.*)?\n/ ) { "<h2>#{$1}</h2>" }   
                generated_response.gsub!( /^#\s+(.*)$/ ) { "<h1>#{$1}</h1>" }
                generated_response.gsub!( /\`(.*?)\`/ ) { "<span class='icode'>#{$1}</span>" } 
                
                # Now bring code blocks back in
                i = -1
                generated_response.gsub!( /ASDASDASDASDASDASDASDASD/ ) do |match|
                  i += 1
                  code_blocks[i].strip
                end
                
                generated_response.gsub!( /\n\n\n/ ) { "\n\n" }
                generated_response.gsub!( /\<pre\>\n/ ) { "<pre>" }
                generated_response.gsub!( /\<\/pre\>\n/ ) { "</pre>" }
                
                if ruby_result != ''
                    generated_response += "\n<h2>Result (from Ruby):</h2><br><pre>#{ruby_result.to_s}</pre>"
                end
                
                js = "add_response(#{generated_response.dump},#{info.dump})"
                
            else
            
                js = "add_response('That did not work. See error below...',#{info.dump})"
                
            end
            
            @dialog.execute_script(js)       
            
            # Cleanup
            @ai_attachment = ""
            js = "jQuery('#attachFile').attr('title','Attach a file').removeClass('active');"
            @dialog.execute_script(js)   


        }  # END add_action_callback("submit_prompt") 
    
    end # openai_explorer_dialog    


    # ==================
    
    
    def self.show_url( title , url )
    # Show website either as a WebDialog or HtmlDialog
    
      if Sketchup.version.to_f < 17 then   # Use old dialog
        @dlg = UI::WebDialog.new( title , true ,
          title.gsub(/\s+/, "_") , 1000 , 600 , 100 , 100 , true);
        @dlg.navigation_buttons_enabled = false
        @dlg.set_url( url )
        @dlg.show      
      else   #Use new dialog
        @dlg = UI::HtmlDialog.new( { :dialog_title => title, :width => 1000, :height => 600,
          :style => UI::HtmlDialog::STYLE_DIALOG, :preferences_key => title.gsub(/\s+/, "_") } )
        @dlg.set_url( url )
        @dlg.show
        @dlg.center
      end  
    
    end      
    

    # ==================   
    
    
    def self.show_help
    # Show the Help website as an About dialog
    
      show_url( "#{@exttitle} - Help" , 'https://alexschreyer.net/projects/openai-explorer-experimental/' )

    end # show_help    
    
    
    # ==================     
    

    def self.show_openai_api
    # Open the OpenAI settings pages that have the API Keys
    # Need it this way for initial open

      UI.openURL('https://platform.openai.com/api-keys')

    end # show_openai_api   


    # ==================       


    def self.reset_settings
    # Resets all extension settings to their defaults
    
      q = "Do you want to reset all of the extension settings to their defaults? This is mainly for troubleshooting purposes."
      if UI.messagebox( q , MB_YESNO ) == 6

        Sketchup.write_default( @extname , "openai_warning" , nil )
        Sketchup.write_default( @extname , "openai_explorer_settings" , nil )
        Sketchup.write_default( @extname , "openai_explorer" , nil )
        Sketchup.write_default( @extname , "ai_explorer_settings_hash" , nil )
        Sketchup.write_default( @extname , "disclaimer_acknowledged" , nil )

        q = "All settings have been reset."
        UI.messagebox( q , MB_OK )
      
      end

    end # reset_settings      

      
    # ==================          


    if !file_loaded?(__FILE__)

      # Add to the SketchUp Extensions menu
      menu = UI.menu("Plugins").add_submenu( @exttitle )
      menu.add_item("AI Explorer Dialog") { self.openai_explorer_dialog }
      menu.add_separator       
      menu.add_item("Get OpenAI API Key") { UI.openURL('https://platform.openai.com/api-keys') }      
      menu.add_item("Check OpenAI API Usage") { UI.openURL('https://platform.openai.com/usage') }
      menu.add_item("View OpenAI Terms of Use") { UI.openURL('https://openai.com/policies/terms-of-use') }
      menu.add_separator 
      menu.add_item("Get Google API Key") { UI.openURL('https://aistudio.google.com/apikey') }  
      menu.add_item("Google API Compatibility") { UI.openURL('https://ai.google.dev/gemini-api/docs/openai#rest') }       
      menu.add_separator       
      menu.add_item("Get Anthropic API Key") { UI.openURL('https://console.anthropic.com/settings/keys') }  
      menu.add_item("Anthropic API Compatibility") { UI.openURL('https://docs.anthropic.com/en/api/openai-sdk') }       
      menu.add_separator       
      menu.add_item("Help") { self.show_help }      
      menu.add_item("Terms of Use") { self.show_disclaimer_window }
      menu.add_item("Reset extension settings") { self.reset_settings }

      # Let Ruby know we have loaded this file
      file_loaded(__FILE__)

    end # if


    # ==================


  end # module AS_OpenAIExplorer

end # module AS_Extensions


# ==================
