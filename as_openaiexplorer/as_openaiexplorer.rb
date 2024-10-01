# ==================
# Main file for OpenAiExplorer
# ==================


require 'sketchup.rb'
require 'net/http'
require 'uri'
require 'json'
require 'base64'


# ==================


module AS_Extensions

  module AS_OpenAIExplorer
  
  
    # Set up some module-wide defaults
    @default_settings = [ 
      "Generate only valid, self-contained SketchUp Ruby code without any method definitions.",  # System Message
      "gpt-3.5-turbo",  # Chat Completion Model
      "256",  # Max. Tokens
      "0.1",  # Temperature
      "Enter your API key here",  # OpenAI API key
      "No",  # Execute code
      "No",  # Submit model view with request
      "low",  # Model view submission quality
      "1"  # Number of submitted messages (user and assistant)
    ]
    
    
    # Create an empty array for all AI messages
    @ai_messages = []    
  
  
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
    
    
    def self.show_disclaimer
    # Shows a disclaimer window once
    
        default = Sketchup.read_default( @extname , "disclaimer_acknowledged" )        
        if default.to_s != "yes" then        
        
            # Show a window with my terms of use
            f = File.join( __dir__ , "license.txt" )
            title = @exttitle + " | Terms of Use"
            if Sketchup.version.to_f < 17 then   # Use old dialog
              @dlg = UI::WebDialog.new( title , true ,
                title.gsub(/\s+/, "_") , 600 , 700 , 100 , 100 , true);
              @dlg.navigation_buttons_enabled = false
              @dlg.set_file( f )
              @dlg.show_modal      
            else   #Use new dialog
              @dlg = UI::HtmlDialog.new( { :dialog_title => title, :width => 600, :height => 700,
                :style => UI::HtmlDialog::STYLE_UTILITY, :preferences_key => title.gsub(/\s+/, "_") } )
              @dlg.set_file( f )
              @dlg.show_modal
              @dlg.center
            end          

            Sketchup.write_default( @extname , "disclaimer_acknowledged" , "yes" )
            
        end 

    end # show_disclaimer


    # ==================
    
    
    def self.openai_explorer_settings
    # Settings dialog

        toolname = "OpenAI Explorer (Experimental) Settings"
        
        # Show disclaimer once
        self.show_disclaimer
        
        # Get all the parameters from input dialog
        prompts = [ "System Message: " , "Chat Completion Model: " , "Max. Tokens [1 to 2048 or 4096]: ", "Temperature [0 to 2.0]: ", "API Key: ", "Execute code: ", "Submit model view with request: ", "Model view submission quality: ", "Submit # of prompts: " ]
        lists = [ "" , "" , "" , "" , "" , "Yes|No", "Yes|No", "low|high", "1|3|5|9" ]
        defaults = Sketchup.read_default( @extname , "openai_explorer_settings" , @default_settings )
        settings = UI.inputbox( prompts , defaults , lists , toolname )
        return if !settings

        Sketchup.write_default( @extname , "openai_explorer_settings" , settings.map { |s| s.gsub( '"' , '' ) } )  # Fix for inch pref saving error
    
    end # openai_explorer_settings
    
    
    # ==================
    
    
    def self.openai_explorer_dialog
    # Opens a connection to the OpenAI API and executes what comes back - uses web dialog
    
        toolname = "OpenAI Explorer (Experimental)"
        
        # Show disclaimer once
        self.show_disclaimer        
        
        # Get the settings, including the API key
        settings = Sketchup.read_default( @extname , "openai_explorer_settings" , @default_settings )     
        
        # Provide a reminder for the API Key when it doesn't have the correct length
        if settings[4].length < 50 then
        
            UI.messagebox("You must enter an OpenAI API Key before you can use this tool. A website will open next where you can obtain one. Once you have it, enter it in the settings dialog for this tool.")
            self.show_openai_api
            self.openai_explorer_settings
            
        else
        
            # Reset the message array on each dialog open
            @ai_messages.clear
        
            # Set up the dialog
            dialog = UI::HtmlDialog.new(
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
            dialog.set_file(File.join(@extdir,@extname,'as_openaiexplorer_ui.html'))
            dialog.show
            dialog.center
            
            # Callback to close dialog
            dialog.add_action_callback("close_dlg") { |action_context|
                dialog.close
            }
            
            # Callback to show settings dialog
            dialog.add_action_callback("settings_dlg") { |action_context|
                self.openai_explorer_settings
            }            
            
            # Callback to submit prompt and get response
            dialog.add_action_callback("submit_prompt") { |action_context,ui_prompt|

                begin

                    mod = Sketchup.active_model # Open model
                    
                    # Get the settings - in case anything changed
                    settings = Sketchup.read_default( @extname , "openai_explorer_settings" , @default_settings )        
                    
                    # Start a timer
                    t1 = Time.now

                    # Start a new undo group
                    mod.start_operation("OpenAI Experiment")

                    # Life is always better with some feedback while SketchUp works
                    Sketchup.status_text = toolname + " | Starting request"
                    info = ""

                    # Set the endpoint and API key for the OpenAI API
                    endpoint = "https://api.openai.com/v1/chat/completions"                
                    api_key = settings[4].to_s

                    # Define the prompt for the code completion
                    prompt = ui_prompt.to_s
                    sys_prompt = settings[0].to_s
                    sys_prompt += " Do not generate any code that affects the file system." if ( settings[5].to_s == "Yes" )
                    puts "\nPrompt ============\n(System:) #{sys_prompt}\n(User:) #{prompt}"
                    
                    # Set up default user mesage (only prompt, no image)
                    user_message = { "role" => "user", "content" => "#{prompt}" }
                    
                    # Modify user mesage if we want to include the model view
                    if ( settings[6].to_s == "Yes" ) 
                        base64_image = encoded_screenshot;
                        user_message = { 
                            "role" => "user", "content" => [
                               { "type" => "text", "text" => "#{prompt}" },
                               { "type" => "image_url", "image_url" => 
                                   { "url" => "data:image/png;base64,#{base64_image}", 
                                     "detail" => "#{settings[7]}" } 
                               }
                             ] }
                             
                        prompt = prompt + "<br /><img src='data:image/png;base64,#{base64_image}' class='thumbnail' title='Submitted view' />"
                    end
                    
                    js = "add_prompt(#{prompt.dump})"
                    dialog.execute_script(js)  
                    
                    # Add the request to the array of messages
                    @ai_messages.push( user_message )

                    # Set up the HTTP request with the API key and prompt
                    uri = URI(endpoint)
                    req = Net::HTTP::Post.new(uri)
                    req["Content-Type"] = "application/json"
                    req["Authorization"] = "Bearer #{api_key}"
                    req.body = JSON.dump({
                      "model" => settings[1].to_s,
                      "messages" => [{ "role" => "system", "content" => "#{sys_prompt}" }] + @ai_messages.last( settings[8].to_i ),
                      "max_tokens" => settings[2].to_i,
                      "top_p" => 1,
                      "n" => 1,
                      "temperature" => settings[3].to_f,
                      "stream" => false
                      # "stop" => "\n"
                    })      

                    # Make the HTTP request to the OpenAI API and parse the response
                    res = Net::HTTP.start(uri.hostname, uri.port, use_ssl: true, read_timeout: 30) do |http|
                      http.request(req)
                    end
                    response_body = JSON.parse(res.body)
                    
                    # Output the raw response for troubleshooting
                    puts "\nRaw Response ============\n"
                    puts response_body
                    
                    # Add the response to the array of messages
                    @ai_messages.push( response_body["choices"][0]["message"] )

                    # Get the generated response from the API response and clean up a bit
                    generated_response = response_body["choices"][0]["message"]["content"]          
                    generated_response.strip!
                    # generated_response.gsub!(/<[^>]*>/,'')  # Strip HTML tags

                    # Display the generated response in the Ruby console
                    puts "\nResult ============\n"
                    puts generated_response

                    # Display some statistics in the Ruby console
                    info += "Tokens used: " + response_body["usage"]["total_tokens"].to_s                    
                    puts "\nStats ============\n"
                    puts info     
                    # puts "Finish reason: " + response_body["choices"][0]["finish_reason"].to_s    

                    # Double-check for a destructive request
                    badwords = ['delete','remove','erase','kill','expunge']
                    isbad = badwords.any? { |w| prompt.downcase.include? w }
                    if ( settings[5].to_s == "Yes" && isbad ) then             
                        delete_check = UI.messagebox "You seem to be asking to delete something. Are you sure you want to execute the generated code?", MB_YESNO
                    else           
                        delete_check = 6
                    end

                    # Execute code only when desired
                    if ( settings[5].to_s == "Yes" && delete_check == 6 )

                        # Life is always better with some feedback while SketchUp works
                        Sketchup.status_text = toolname + " | Executing code"         

                        # Extract the generated code
                        if generated_response.include? "```"     # For quoted code
                            generated_code = generated_response[/```ruby(.*?)```/m, 1].strip! 
                            info += " | Code was executed."
                        else
                            generated_code = ''   # generated_response   previously for older models that did not quote
                            info += " | No usable code in the response."
                        end
                        
                        # Execute it
                        eval generated_code

                    else

                        nocode = "No code was executed. You can turn this feature on in the extension's settings."
                        info += " | " + nocode
                        puts nocode

                    end      

                    # Life is always better with some feedback while SketchUp works
                    Sketchup.status_text = toolname + " | Done"     

                    # Finish a new undo group
                    mod.commit_operation

                 rescue Exception => e    
                 
                    errmsg = ""
                     
                    # Provide an error message for OpenAI errors if they get returned
                    if ( defined?(response_body['error']['message']) != nil ) then
                        errmsg += "<b>(OpenAI:)</b> #{response_body['error']['message']} "
                    end                     

                    # Provide an error message for SketchUp errors
                    errmsg += "<b>(SketchUp:)</b> #{e}. "

                    puts "This request generated an error. See dialog for details.\n"                

                end    
                
                # Measure duration
                duration = Time.now - t1
                info += " | Time elapsed: %0.2fs" % duration     
                
                # Did we get an error?
                info += " | <span class='error'><strong>ERROR:</strong> " + errmsg + "</span>" if errmsg != nil
 
                # Display result and stats in the dialog
                if generated_response!=nil
                    # Clean up output a bit
                    generated_response.gsub!( /\*\*(.*)\*\*/ ) { "<b>#{$1}</b>" }
                    generated_response.gsub!( /\*(.*)\*/ ) { "<i>#{$1}</i>" }
                    generated_response.gsub!( /\`\`\`[^\s]+\n/, "<code>" )
                    generated_response.gsub!( /\`\`\`\n/, "</code>" )
                    # generated_response.gsub!( /\`(.*)\`/ ) { "<code>#{$1}</code>" }                 
                    generated_response.gsub!( /```/, "" )
                    js = "add_response(#{generated_response.dump},#{info.dump})"
                else
                    js = "add_response('That did not work. See error below...',#{info.dump})"
                end
                
                dialog.execute_script(js)                

            }  # END add_action_callback("submit_prompt")
            
        end    
    
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
    # Open the OpenAI settings page that has the API Key

      UI.openURL('https://platform.openai.com/account/api-keys')

    end # show_openai_api   
    
    
    # ==================      


    def self.show_openai_tou
    # Open the OpenAI settings page that has the API Key

      UI.openURL('https://openai.com/policies/terms-of-use')

    end # show_openai_tou       
    
    
    # ==================      


    def self.reset_settings
    # Resets all extension settings to their defaults
    
      q = "Do you want to reset all of the extension settings to their defaults? This is mainly for troubleshooting purposes."
      if UI.messagebox( q , MB_YESNO ) == 6

        Sketchup.write_default( @extname , "openai_warning" , nil )
        Sketchup.write_default( @extname , "openai_explorer_settings" , nil )
        Sketchup.write_default( @extname , "openai_explorer" , nil )
        Sketchup.write_default( @extname , "disclaimer_acknowledged" , nil )

        q = "All settings have been reset."
        UI.messagebox( q , MB_OK )
      
      end

    end # reset_settings      

      
    # ==================          


    if !file_loaded?(__FILE__)

      # Add to the SketchUp Extensions menu
      menu = UI.menu("Plugins").add_submenu( @exttitle )
      menu.add_item("OpenAI Explorer Dialog") { self.openai_explorer_dialog }
      menu.add_item("OpenAI Explorer Settings") { self.openai_explorer_settings }
      menu.add_item("Get OpenAI API Key") { self.show_openai_api }
      menu.add_separator      
      menu.add_item("OpenAI Terms of Use") { self.show_openai_tou }
      menu.add_item("Reset extension settings") { self.reset_settings }
      menu.add_item("Help") { self.show_help }

      # Let Ruby know we have loaded this file
      file_loaded(__FILE__)

    end # if


    # ==================


  end # module AS_OpenAIExplorer

end # module AS_Extensions


# ==================
