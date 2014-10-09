require "sinatra"     # Load the Sinatra web framework
require "data_mapper" # Load the DataMapper database library

require "./database_setup"

class Message
  include DataMapper::Resource
  property :id,         Serial
  property :body,       Text,     required: true
  property :created_at, DateTime, required: true
  #property :likes,      Integer,  required: true
  #property :likes,      String,   required: true
  #property :dislikes,   Integer,  required: true
  property :shown,      Integer,  required: true
  property :user_id,    Integer,  required: true
  
  def likes_tostring()
    temp = ""
    num = 0
    likes = Like.all()
    likes.each do |like|
      if like.message_id == self.id and like.type == "message" then
        temp += User.get(like.user_id).name << ", " 
        num = num + 1
      end
    end
    if num == 0 then 
      return "No likes."
    elsif num == 1 then
      temp = temp.delete! ","
      temp += "likes this."
    else
      temp += " like this."
    end
    return temp
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
  #property :likes,      Integer,  required: true, default: 0
  #property :likes,     Array,    required: true, default: Array.new 
  #property :dislikes,   Integer,  required: true, default: 0
  property :shown,      Integer,  required: true, default: 1
  property :user_id,    Integer,  required: true
  
  property :parentId,   Integer,  required: true
  
  def hide()
    self.shown = 0
  end
end

class Like
  include DataMapper::Resource
  property :id,         Serial
  property :type,       String,  required: true
  property :user_id,    Integer, required: true
  property :message_id, Integer, required: true
end

=begin
class Hate
  include DataMapper::Resource
  property :id,         Serial,  required: true
  property :user_id,    Integer, required: true
  property :message_id, Integer, required: true
end
=end

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
  records4 = Like.all()
  puts session[:user_id]
  user = User.find_by_id(session[:user_id])
  erb(:index, locals: { messages: records, comments: records2, users: records3, loggedUser: user, likes: records4 } )
end

post ("/messageLike/*/*") do |id,userId|
  records = Message.all(order: :created_at.desc)
  message = Message.get(id)
  
  user = User.find_by_id(userId)
  #message.likes.insert(user.likes.length, user.name << ",")
  
  like = Like.new(message_id: id, user_id: userId, type: "message");
  like.save
  
  #message.save
  redirect("/")
end

post ("/messageImplode/*") do |id|
  records = Message.all(order: :created_at.desc)
  message = Message.get(id)
  message.hide()
  message.save
  redirect("/")
end

post ("/commentLike/*/*") do |id,userId|
  records = Comment.all(order: :created_at.desc)
  comment = Comment.get(id)
  
  user = User.find_by_id(userId)
  #message.likes.insert(user.likes.length, user.name << ",")
  
  like = Like.new(message_id: id, user_id: userId, type: "comment");
  like.save
  
  #message.save
  redirect("/")
end

=begin
post ("/commentHate/*") do |id|
  comment = Comment.get(id)
  comment.subLike()
  comment.save
  redirect("/")
end
=end

post ("/commentImplode/*") do |id|
  comment = Comment.get(id)
  comment.hide()
  comment.save
  redirect("/")
end

post("/register") do
  username = params["username"]
  password = params["password"]
  
  if User.find_by_name(username) == nil then
    user = User.create(name: username, password: password)
    user.save
  end
  
  redirect("/")
end

post("/signin") do
  username = params["username"]
  password = params["password"]
  
  user = User.find_by_name(username)
  if user.password == password then
    session[:user_id] = user.id
  end
  
  redirect("/")
end

post("/messages") do

  user = User.find_by_id(session[:user_id]);

  message = Message.create(body: params["body"], created_at: DateTime.now, shown: 1, user_id: user.id)
  #message = Message.new(params["body"], DateTime.now, 0, 1, user.name)
  #message.likes = Array.new
  
  #message = Message.create
  #message.body = params["body"]
  #message.created_at = DateTime.now
  #message.dislikes = 0
  #message.shown = 1
  #message.user_creator = user.name
  
  message.save
  redirect("/")
end

post("/comments/*") do |id|
  
  user = User.find_by_id(session[:user_id]);
  comment = Comment.create(body: params["body"], created_at: DateTime.now, shown: 1, user_id: user.id, parentId: id)
  
  if comment.saved?
    redirect("/")
  else
    erb(:error)
  end
  
end
