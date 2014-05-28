require "bundler"
Bundler.require(:default)

# Configure JTask environment settings
JTask.configure do |config|
  config.file_dir = "storage"
end

class Origami < Sinatra::Base
  # Allow sessions & cookie data to be used
  set :sessions, true
  helpers Sinatra::Cookies

  helpers do
    # Require each file (containing various functions) from the `/helpers` directory.
    Dir["./helpers/*.rb"].each &method(:require)
  end

  before do
    # automatically signs the user in if the `autologin` cookie is present
    if cookies[:autologin]
      @user = JTask.get("users.json", 1)
      # if the username and password match the one in storage
      if @user.username == cookies[:autologin][:username] && @user.password == BCrypt::Engine.hash_secret(cookies[:autologin][:password], @user.salt)
        session[:user] = @user.id
      else
        session[:notification] = ["error", "Could not automatically sign in because your username or password has changed."]
        redirect "/login"
      end
    end
  end

  #############################################################
  # MAIN APPLICATION LOGIC ####################################
  #############################################################

  # When a user visits the home page
  get "/" do
    authenticate!
    # render the homepage UI
    erb :index
  end

  post "/api" do
    authenticate!
  end

  get "/settings" do
    authenticate!
    @user = JTask.get("users.json", current_user)
    erb :settings
  end

  post "/settings" do
    authenticate!
    # Update the user with the username specified
    JTask.update("users.json", current_user, username: params[:username])
    # If the new passwords don't match, display an error message.
    if params[:new_password] != params[:confirm_password]
      session[:notification] = ["warning", "<b>Warning:</b> Your system preferences couldn't be updated because your new passwords don't match."]
      redirect "/settings"
    end
    # We don't want to update a password if the field has been
    # left intentionally blank.
    unless params[:new_password] == ""
      salt = BCrypt::Engine.generate_salt
      hashed_password = BCrypt::Engine.hash_secret(params[:new_password], salt)
      JTask.update("users.json", session[:user], {password: hashed_password, salt: salt})
    end
    session[:notification] = ["info", "<b>Nice.</b> Your system preferences have been successfully updated."]
    redirect "/settings"
  end


  #############################################################
  # USER ACCOUNTS ROUTES ######################################
  #############################################################
  get "/login" do
    # redirect the user if they are already signed in
    if current_user
      session[:notification] = ["warning", "You're already signed in!"]
      redirect "/"
    end
    # otherwise render the login UI
    @no_content_bg = true
    erb :login
  end

  post "/new_session" do
    @user = JTask.get("users.json", 1)
    # if the username and password match the one in storage
    if @user.username == params[:username] && @user.password == BCrypt::Engine.hash_secret(params[:password], @user.salt)
      session[:user] = @user.id
      # If "stay signed in?" is checked
      if params[:autologin] == 1
        # expires in 14 days
        response.set_cookie(:autologin, :value => {:username => params[:username], :password => params[:password]}, :expires => Time.now + 3600*24*14)
      end
      redirect "/"
    else
      session[:notification] = ["error", "<b>Oops.</b> The login information you used appears to be invalid."]
      redirect "/login"
    end
  end

  get "/logout" do
    session[:user] = nil
    cookies[:autologin] = nil
    session[:notification] = ["success", "<b>All clear.</b> You have been signed out successfully."]
    redirect "/login"
  end
end