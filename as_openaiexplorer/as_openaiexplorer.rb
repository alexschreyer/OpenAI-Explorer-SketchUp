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
    
    
    def self.show_warning
    # Shows a warning once   
    
        default = Sketchup.read_default( @extname , "openai_warning" )
        if default.to_s != "1" then
            prompt = "By clicking OK you acknowledge that this is an experimental extension and that it is able to automate SketchUp using its Ruby scripting engine. Use at your own risk!"
            prompt += "\n\nTHIS SOFTWARE IS PROVIDED 'AS IS' AND WITHOUT ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, WITHOUT LIMITATION, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE."
            res = UI.messagebox( prompt, MB_OK )
            Sketchup.write_default( @extname , "openai_warning" , res )
        end 

    end # show_warning

    # ==================
    
    
    def self.openai_explorer_settings
    # Settings dialog

        toolname = "OpenAI Explorer Settings (Experimental)"
        
        # Show warning once
        self.show_warning
        
        # Get all the parameters from input dialog
        prompts = [ "Prompt Prefix: " , "Model: " , "Max. Tokens [1 to 2048 or 4096]: ", "Temperature [0 to 2.0]: ", "API Key: ", "Execute code: " ]
        defaults = [ "Use SketchUp Ruby" , "text-davinci-003" , "256", "0", "Enter your API key here", "Yes" ]
        lists = [ "Use SketchUp Ruby|None" , "" , "" , "" , "" , "Yes|No" ]
        defaults = Sketchup.read_default( @extname , "openai_explorer_settings" , defaults )
        settings = UI.inputbox( prompts , defaults , lists , toolname )
        return if !settings

        Sketchup.write_default( @extname , "openai_explorer_settings" , settings.map { |s| s.gsub( '"' , '' ) } )  # Fix for inch pref saving error
    
    end # openai_explorer_settings
    
    
    # ==================
    

    def self.openai_explorer
    # Opens a connection to the OpenAI API and executes what comes back

        toolname = "OpenAI Explorer (Experimental)"
        
        # Show warning once
        self.show_warning        
        
        # Get the settings, including the API key
        defaults = [ "Use SketchUp Ruby" , "text-davinci-003" , "256", "0", "", "Yes" ]
        settings = Sketchup.read_default( @extname , "openai_explorer_settings" , defaults )     
        
        # Provide a reminder for the API Key when it doesn't have the correct length
        if settings[4].length < 50 then
        
            UI.messagebox("You must enter an API Key before you can use this tool. A website will open next where you can obtain one. Once you have it, enter it in the settings dialog for this tool.")
            self.show_openai_api
            self.openai_explorer_settings
        
        else

            # Get all the parameters from defaults and the input dialog
            prompts = [ "Ask the AI something: " ]
            defaults = [ "Draw a 2 inch box" ]
            defaults = Sketchup.read_default( @extname , "openai_explorer" , defaults )
            main_prompt = UI.inputbox( prompts , defaults , toolname )
            return if !main_prompt

            Sketchup.write_default( @extname , "openai_explorer" , main_prompt.map { |s| s.gsub( '"' , '' ) } )  # Fix for inch pref saving error      

            begin

                mod = Sketchup.active_model # Open model

                # Always show the Ruby console so that we can see the generated code
                SKETCHUP_CONSOLE.show

                # Start a new undo group
                mod.start_operation("OpenAI Experiment")

                # Life is always better with some feedback while SketchUp works
                Sketchup.status_text = toolname + " | Starting request"

                # Set the endpoint and API key for the OpenAI API
                endpoint = "https://api.openai.com/v1/completions"
                api_key = settings[4].to_s

                # Define the prompt for the code completion
                prompt = ""
                prompt += settings[0].to_s + "\n" if settings[0].to_s != "None"
                prompt += main_prompt[0].to_s
                puts "\nPrompt ============\n" + prompt

                # Set up the HTTP request with the API key and prompt
                uri = URI(endpoint)
                req = Net::HTTP::Post.new(uri)
                req["Content-Type"] = "application/json"
                req["Authorization"] = "Bearer #{api_key}"
                req.body = JSON.dump({
                  "model" => settings[1].to_s,
                  "prompt" => prompt,
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
                generated_code = response_body["choices"][0]["text"]            
                generated_code.strip!
                generated_code.gsub!(/<[^>]*>/,'')  # Strip HTML tags

                # Display the generated code in the Ruby console
                puts "\nResult ============\n"
                puts generated_code

                # Execute code only when desired
                if ( settings[5].to_s == "Yes" )

                    # Life is always better with some feedback while SketchUp works
                    Sketchup.status_text = toolname + " | Executing code"            

                    # Run the generated code - fingers crossed!
                    eval generated_code    

                end
                
                # Display some statistics in the Ruby console
                puts "\nRequest Stats ============\n"
                puts "Tokens used: " + response_body["usage"]["total_tokens"].to_s     
                # puts "Finish reason: " + response_body["choices"][0]["finish_reason"].to_s

                # Life is always better with some feedback while SketchUp works
                Sketchup.status_text = toolname + " | Done"     

                # Finish a new undo group
                mod.commit_operation

             rescue Exception => e    

                # Provide an error message for SketchUp errors
                errmsg = "Couldn't do it!\n\nSketchUp error: #{e}"
                
                # And provide one for OpenAI errors if they get returned
                if ( defined?(response_body['error']['message']) != nil ) then
                    errmsg += "\n\nOpenAI error: #{response_body['error']['message']}"
                end
                
                UI.messagebox( errmsg )

            end     
            
        end

    end # openai_explorer


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


    if !file_loaded?(__FILE__)

      # Add to the SketchUp Extensions menu
      menu = UI.menu("Plugins").add_submenu( @exttitle )
      menu.add_item("OpenAI Explorer") { self.openai_explorer }
      menu.add_item("OpenAI Settings") { self.openai_explorer_settings }
      menu.add_item("Get OpenAI API Key") { self.show_openai_api }
      menu.add_separator      
      menu.add_item( "Help" ) { self.show_help }

      # Let Ruby know we have loaded this file
      file_loaded(__FILE__)

    end # if


    # ==================


  end # module AS_OpenAIExplorer

end # module AS_Extensions


# ==================
