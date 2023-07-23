# ==================
# Main file for OpenAiExplorer
# ==================


require 'sketchup.rb'
require 'net/http'
require 'uri'
require 'json'


# ==================


module AS_Extensions

  module AS_OpenAIExplorer
  
  
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
        prompts = [ "Prompt Prefix / System Message: " , "Chat Completion Model: " , "Max. Tokens [1 to 2048 or 4096]: ", "Temperature [0 to 2.0]: ", "API Key: ", "Execute code: " ]
        defaults = [ "Use SketchUp Ruby" , "gpt-3.5-turbo" , "256", "0", "Enter your API key here", "No" ]
        lists = [ "" , "" , "" , "" , "" , "Yes|No" ]
        defaults = Sketchup.read_default( @extname , "openai_explorer_settings" , defaults )
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
        defaults = [ "Use SketchUp Ruby" , "gpt-3.5-turbo" , "256", "0", "", "No" ]
        settings = Sketchup.read_default( @extname , "openai_explorer_settings" , defaults )     
        
        # Provide a reminder for the API Key when it doesn't have the correct length
        if settings[4].length < 50 then
        
            UI.messagebox("You must enter an OpenAI API Key before you can use this tool. A website will open next where you can obtain one. Once you have it, enter it in the settings dialog for this tool.")
            self.show_openai_api
            self.openai_explorer_settings
            
        else
        
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
                    defaults = [ "Use SketchUp Ruby" , "gpt-3.5-turbo" , "256", "0", "", "No" ]
                    settings = Sketchup.read_default( @extname , "openai_explorer_settings" , defaults )                         

                    # Start a new undo group
                    mod.start_operation("OpenAI Experiment")

                    # Life is always better with some feedback while SketchUp works
                    Sketchup.status_text = toolname + " | Starting request"

                    # Set the endpoint and API key for the OpenAI API
                    endpoint = "https://api.openai.com/v1/chat/completions"                
                    api_key = settings[4].to_s

                    # Define the prompt for the code completion
                    prompt = ""
                    prompt += "# #{settings[0].to_s}\n" if settings[0].to_s != ""
                    prompt += "# #{ui_prompt.to_s}"
                    puts "\nPrompt ============\n" + prompt
                    
                    js = "add_prompt(#{prompt.dump})"
                    dialog.execute_script(js)                    

                    # Set up the HTTP request with the API key and prompt
                    uri = URI(endpoint)
                    req = Net::HTTP::Post.new(uri)
                    req["Content-Type"] = "application/json"
                    req["Authorization"] = "Bearer #{api_key}"
                    req.body = JSON.dump({
                      "model" => settings[1].to_s,
                      "messages" => [ "role" => "user", "content" => prompt ],
                      "max_tokens" => settings[2].to_i,
                      "top_p" => 1,
                      "n" => 1,
                      "temperature" => settings[3].to_f,
                      "stream" => false
                      # "stop" => "\n"
                    })                                

                    # Make the HTTP request to the OpenAI API and parse the response
                    res = Net::HTTP.start(uri.hostname, uri.port, use_ssl: true) do |http|
                      http.request(req)
                    end
                    response_body = JSON.parse(res.body)

                    # Get the generated code from the API response and clean up a bit
                    generated_code = response_body["choices"][0]["message"]["content"]          
                    generated_code.strip!
                    generated_code.gsub!(/<[^>]*>/,'')  # Strip HTML tags

                    # Display the generated code in the Ruby console
                    puts "\nResult ============\n"
                    puts generated_code

                    # Display some statistics in the Ruby console
                    info = "Tokens used: " + response_body["usage"]["total_tokens"].to_s                    
                    puts "\nStats ============\n"
                    puts info     
                    # puts "Finish reason: " + response_body["choices"][0]["finish_reason"].to_s    

                    # Double-check for a destructive request
                    badwords = ['delete','remove','erase','kill','expunge']
                    isbad = badwords.any? { |w| prompt.downcase.include? w }
                    if isbad then             
                        delete_check = UI.messagebox "You are asking to delete something. Are you sure you want to execute the generated code?", MB_YESNO
                    else           
                        delete_check = 6
                    end

                    # Execute code only when desired
                    if ( settings[5].to_s == "Yes" && delete_check == 6 )

                        # Life is always better with some feedback while SketchUp works
                        Sketchup.status_text = toolname + " | Executing code"         
                        
                        info += " | Code was executed."

                        # Run the generated code - fingers crossed!
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

                    # Provide an error message for SketchUp errors
                    errmsg = "(SketchUp error) #{e}. "

                    # And provide one for OpenAI errors if they get returned
                    if ( defined?(response_body['error']['message']) != nil ) then
                        errmsg += "(OpenAI error) #{response_body['error']['message']}"
                    end

                    puts "This request generated an error\n"                
                    info += " | <span class='error'><strong>ERROR:</strong> " + errmsg + "</span>"

                end    
                
                # Display result and stats in the dialog
                js = "add_response(#{generated_code.dump},#{info.dump})"
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


    if !file_loaded?(__FILE__)

      # Add to the SketchUp Extensions menu
      menu = UI.menu("Plugins").add_submenu( @exttitle )
      menu.add_item("OpenAI Explorer Dialog") { self.openai_explorer_dialog }
      menu.add_item("OpenAI Explorer Settings") { self.openai_explorer_settings }
      menu.add_item("Get OpenAI API Key") { self.show_openai_api }
      menu.add_separator      
      menu.add_item("OpenAI Terms of Use") { self.show_openai_tou }
      menu.add_item( "Help" ) { self.show_help }

      # Let Ruby know we have loaded this file
      file_loaded(__FILE__)

    end # if


    # ==================


  end # module AS_OpenAIExplorer

end # module AS_Extensions


# ==================
