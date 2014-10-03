require "sinatra"     # Load the Sinatra web framework
require "data_mapper" # Load the DataMapper database library

require "./database_setup"

class Message
  include DataMapper::Resource
  property :id,         Serial
  property :body,       Text,     required: true
  property :created_at, DateTime, required: true
  property :likes,      Integer,  required: true
  property :dislikes,   Integer,  required: true
  property :shown,      Integer,  required: true
  property :user_creator, String, required: true
  
  def addLike() 
    self.likes += 1 
  end
  def subLike() 
    self.dislikes += 1 
  end
  def hide()
    self.shown = 0
  end
end

class User
  include DataMapper::Resource
  property :id,       Serial
  property :name,     String, required: true
  property :password, String, required: true
  
  def self.find_by_name(name)
    self.first(:name => name)
  end
  
  def self.find_by_id(id)
    self.first(:id => id)
  end
end

class Comment
  include DataMapper::Resource
  property :id,         Serial
  property :body,       Text,     required: true
  property :created_at, DateTime, required: true
  property :likes,      Integer,  required: true
  property :dislikes,   Integer,  required: true
  property :shown,      Integer,  required: true
  property :user_creator, String, required: true
  
  property :parentId,   Integer,  required: true
  
  def addLike() 
    self.likes += 1 
  end
  def subLike() 
    self.dislikes += 1 
  end
  def hide()
    self.shown = 0
  end
end

DataMapper.finalize()
DataMapper.auto_upgrade!()

enable :sessions

def current_user
  # Return nil if no user is logged in
  return nil unless session[:user_id] != nil
  # If @current_user is undefined, define it by
  # fetching it from the database.
  @current_user = User.find_by_id(session[:user_id])
end

get("/") do
  records = Message.all(order: :created_at.desc)
  records2 = Comment.all(order: :created_at.desc)
  records3 = User.all()
  puts session[:user_id]
  user = User.find_by_id(session[:user_id])
  erb(:index, locals: { messages: records, comments: records2, users: records3, loggedUser: user } )
end

post ("/messageLike/*") do |id|
  records = Message.all(order: :created_at.desc)
  message = Message.get(id)
  message.addLike()
  message.save
  redirect("/")
end

post ("/messageHate/*") do |id|
  records = Message.all(order: :created_at.desc)
  message = Message.get(id)
  message.subLike()
  message.save
  redirect("/")
end

post ("/messageImplode/*") do |id|
  records = Message.all(order: :created_at.desc)
  message = Message.get(id)
  message.hide()
  message.save
  redirect("/")
end

post ("/commentLike/*") do |id|
  puts id
  comment = Comment.get(id)
  comment.addLike()
  comment.save
  redirect("/")
end

post ("/commentHate/*") do |id|
  comment = Comment.get(id)
  comment.subLike()
  comment.save
  redirect("/")
end

post ("/commentImplode/*") do |id|
  comment = Comment.get(id)
  comment.hide()
  comment.save
  redirect("/")
end

post("/register") do
  username = params["username"]
  password = params["password"]
  
  user = User.create(name: username, password: password)
  user.save
  #current_user = user
  redirect("/")
end

post("/signin") do
  username = params["username"]
  password = params["password"]
  
  user = User.find_by_name(username)
  if user.password == password then
    session[:user_id] = user.id
    #puts session[:user_id]
    #@current_user = user
    #records = Message.all(order: :created_at.desc)
    #records2 = Comment.all(order: :created_at.desc)
    #records3 = User.all()
    #erb(:index, :locals => { messages: records, comments: records2, users: records3, :loggedUser => user })
    #erb(:index, locals: { messages: records, comments: records2, users: records3, loggedUser: user })
    #redirect("/")
    #puts user.id
  end
  
  redirect("/")
end

post("/messages") do

  message_body = params["body"]
  
  user = User.find_by_id(session[:user_id]);

  message = Message.create(body: params["body"], created_at: DateTime.now, likes: 0, dislikes: 0, shown: 1, user_creator: user.name)

  if message.saved?
    redirect("/")
  else
    erb(:error)
  end
end

post("/comments/*") do |id|
  
  user = User.find_by_id(session[:user_id]);
  comment = Comment.create(body: params["body"], created_at: DateTime.now, likes: 0, dislikes: 0, shown: 1, user_creator: user.name, parentId: id)
  
  if comment.saved?
    redirect("/")
  else
    erb(:error)
  end
  
end
