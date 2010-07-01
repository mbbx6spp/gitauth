#--
#   Copyright (C) 2009 Brown Beagle Software
#   Copyright (C) 2009 Darcy Laycock <sutto@sutto.net>
#   Copyright (C) 2009 Nokia Corporation and/or its subsidiary(-ies)
#   Copyright (C) 2007, 2008 Johan Sørensen <johan@johansorensen.com>
#   Copyright (C) 2008 Tor Arne Vestbø <tavestbo@trolltech.com>
#
#   This program is free software: you can redistribute it and/or modify
#   it under the terms of the GNU Affero General Public License as published by
#   the Free Software Foundation, either version 3 of the License, or
#   (at your option) any later version.
#
#   This program is distributed in the hope that it will be useful,
#   but WITHOUT ANY WARRANTY; without even the implied warranty of
#   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#   GNU Affero General Public License for more details.
#
#   You should have received a copy of the GNU Affero General Public License
#   along with this program.  If not, see <http://www.gnu.org/licenses/>.
#++

module GitAuth
  class Client
    include GitAuth::Loggable
    
    attr_accessor :user, :command
    
    def initialize(user_name, command)
      logger.debug "Initializing client with command: #{command.inspect} and user name #{user_name.inspect}"
      @callbacks = Hash.new { |h,k| h[k] = [] }
      @user      = GitAuth::User.get(user_name.to_s.strip)
      @command   = command
    end
    
    def exit_with_error(error)
      logger.warn "Exiting with error: #{error}"
      $stderr.puts error
      exit! 1
    end
    
    def run!
      if @user.nil?
        exit_with_error "An invalid user / key was used. Please ensure it is setup with GitAuth"
      elsif @command.to_s.strip.empty?
        if user.shell_accessible?
          exec(ENV["SHELL"])
        else
          exit_with_error "SSH_ORIGINAL_COMMAND is needed, mmmkay?"
        end
      else
        command   = Command.parse(@command)
        repo      = command.bad? ? nil : Repo.get(extract_repo_name(command))
        if command.bad?
          if user.shell_accessible?
            exec(@command)
          else
            exit_with_error "Invalid ssh command - Access Denied"
          end
        elsif repo.nil?
          exit_with_error "Unable to push to a non-existant repository"
        elsif user.can_execute?(command, repo)
          git_shell_argument = "#{command.verb} '#{repo.real_path}'"
          logger.info "Running command: #{git_shell_argument} for user: #{@user.name}"
          exec("git-shell", "-c", git_shell_argument)
        else
          exit_with_error "Unable to execute command on this repository"
        end
      end
    rescue Exception => e
      logger.fatal "Exception: #{e.class.name}: #{e.message}"
      e.backtrace.each do |l|
        logger.fatal "  => #{l}"
      end
      exit_with_error "Exception raised - Please check your gitauth log / contact an administrator"
    end
    
    def self.start!(user, command)
      # Gitorious does it so I should too!
      File.umask(0022)
      # Setup models etc
      GitAuth.prepare
      # Finally, create and initialize
      client = self.new(user, command)
      yield client if block_given?
      client.run!
    end
    
    protected
    
    def extract_repo_name(command)
      command.path
    end
    
  end
end
