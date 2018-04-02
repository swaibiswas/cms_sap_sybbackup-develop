#
# Helper functions that could be used by TSM resources/recipes.
#

module Common
  module Helper
    # Creates a target file on a location replacing the tokens with desired param
    def self.replace_sid(src_filename, target_filename, token, value)
      File.open(src_filename, 'r') do |src_file|
        File.open(target_filename, 'w') do |trgt_file|
          src_file.each_line do |line|
            proc_line = line.gsub(/@#{token}@/, value)
            trgt_file.puts proc_line
          end
        end
      end
    end

    ## Checks the return code of the file. The last line must be (return status = 0)
    ## If not so, is an indication that it failed.
    def self.validate_last_retcode(src_file)
      handle = File.open(src_file).to_a
      last_line = handle.last
      r = /^\(return\sstatus/
      code = /(\d+)/
      puts last_line
      # Any non-zero return code
      ret_code = 1
      ret_code = (code.match last_line)[0].to_i if last_line =~ r
      raise "Exiting as non-zero code found. Log can be checked at #{src_file}." if ret_code != 0
    end

    ## Checks the return codes in the file. Use this when all return codes must be 0.
    def self.validate_all_retcode(src_file)
      r = /^\(return\sstatus/
      code = /(\d+)/
      flag = false
      File.open(src_file, 'r') do |handle|
        handle.each_line do |line|
          puts line
          next unless line =~ r
          ret_code = code.match line
          flag = true if ret_code[0].to_i != 0
        end
      end
      raise 'Non-zero return code was found. Operation did not complete successfully.' if flag == true
    end

    # Parse the output of sybase files to verify return status.
    # Assumptions: If a procedure is called,then the following statementif has "already" word, then ignore the return status.
    # If the procedure does not have already, then return code will decide if the operation failed or succeeded.
    # Return code = 0 - if any operation succeeds.
    def self.validate_out(src_file)
      r = /Procedure 'sp_(.*)/
      alr = /already/
      code = /(-*)(\d+)/
      ret = /^\(return\sstatus/
      proc_found = false
      alr_found = false
      err_flag = false

      File.open(src_file, 'r') do |handle|
        handle.each_line do |line|
          next if line.strip.empty?
          puts line
          if proc_found == false
            if line =~ r
              proc_found = true
            elsif line =~ ret
              # Its not a stored procedure, check the return status and if non-zero flag it.
              ret_code = code.match line
              err_flag = true if ret_code[0].to_i != 0
            end
          elsif alr_found == false
            if line =~ alr
              # It is a stored procedure, and "already word found."
              alr_found = true
            elsif line =~ ret
              # It is a stored procedure and logs des not contain "already"
              # Check the return status, if non-zero flag the error.
              # Reset the procedure flag.
              ret_code = code.match line
              err_flag = true if ret_code[0].to_i != 0
              proc_found = false
            end
          elsif line =~ ret
            # This is the case where both procedure and already was found.
            # Thus ignore the return code and reset the flags.
            proc_found = false
            alr_found = false
          end
        end
      end
      raise 'Non-zero return code found. Exiting.' if err_flag == true
    end

    # Creates a target file on a location replacing multiple tokens with desired value
    def self.replace_tokens(src_filename, target_filename, tokens_values)
      File.open(src_filename, 'r') do |src_file|
        File.open(target_filename, 'w') do |trgt_file|
          src_file.each_line do |line|
            proc_line = line
            tokens_values.each do |token, value|
              proc_line = proc_line.gsub(/@#{token}@/, value)
            end
            trgt_file.puts proc_line
          end
        end
      end
    end

    # Extract paramvalue for a given stanza - mostly filesystem stanza
    def self.getdsmsysvalue(fsserver, filename, paramname)
      servername = 'SERVERNAME'
      flag = false
      r = /^#{servername}/i
      rp = /^#{paramname}/i
      File.open filename do |file|
        file.find do |line|
          if line =~ r
            sub_str = (line.gsub! r, '').strip
            # Skip the lines until the stanza found.
            next if fsserver != sub_str
            flag = true
          end
          # Only when the stanza is found, look for the parameter
          next unless flag == true
          return (line.gsub! rp, '').strip if line =~ rp
        end
      end
    end

    # Find if db stanzas TSM-SYB & SYB-LOG already exists
    def self.isstanzapresent(server, filename)
      servername = 'SERVERNAME'
      flag = false
      r = /^#{servername}/i
      File.open filename do |file|
        file.find do |line|
          next unless line =~ r
          sub_str = (line.gsub! r, '').strip
          next if server.upcase != sub_str.upcase
          flag = true
        end
      end
      # Return boolean indicating whether the stanza exists in dsm.sys file or not.
      flag
    end

    # Extract paramaeter value from dsm config files
    def self.getparamvalue(paramname, filename)
      r = /^#{paramname}/i
      File.open filename do |file|
        file.find do |line|
          line = line.strip
          next unless line =~ r
          value = (line.gsub! r, '')
          return value.strip
        end
      end
    end

    # Set node password by executing sybtsmpasswd.
    def self.execute_sybtsmpasswd(sybtsmpasswd, nodeoldpwd, nodenewpwd)
      require 'pty'
      require 'expect'

      # Uncooment the following line to see the run time responses.
      # $expect_verbose = true
      result = ''
      PTY.spawn(sybtsmpasswd) do |r, w, _pid|
        w.sync = true
        r.expect(/^Enter your current password:/) do
          w.print "#{nodeoldpwd}\n"
        end
        r.expect(/^Enter your new password:/) do
          w.print "#{nodenewpwd}\n"
        end
        r.expect(/^Enter your new password .*:/) do
          w.print "#{nodenewpwd}\n"
        end
        # Add this step so that final status can be captured
        r.expect(/[.!]$/) do |op|
          result = op
        end
      end
      # Returns an array.
      result = result.join().strip
      puts "\n\nResult obtained: #{result}"
      result
    end

    def self.isexprpresent(filename, expr)
      flag = false
      File.open filename do |file|
        file.find do |line|
          flag = true if line =~ /^#{expr}/i
        end
      end
      # Return boolean indicating whether the expression exist in file or not.
      flag
    end
  end
end
