require "sinatra"     # Load the Sinatra web framework
require "data_mapper" # Load the DataMapper database library

require "./database_setup"
require "dm-validations";

class Message
  include DataMapper::Resource
  property :id,         Serial
  property :body,       Text,     required: true
  property :created_at, DateTime, required: true
  property :shown,      Integer,  required: true
  
  has n, :comments
  has n, :messageLikes
  belongs_to :user
  #validates_length_of :name, :min => 1
  
  def hide()
    self.shown = 0
  end
end

=begin
class UserProfile
  include DataMapper::Resource
  property :id, Serial
  
  has 1, :user
end
=end

class Comment
  include DataMapper::Resource
  property :id,         Serial
  property :body,       Text,     required: true
  property :created_at, DateTime, required: true
  property :shown,      Integer,  required: true, default: 1
  
  has n, :commentLikes
  belongs_to :user
  belongs_to :message
  #validates_length_of :body, :min => 1

  def hide()
    self.shown = 0
  end
end

class MessageLike
  include DataMapper::Resource
  property :id,         Serial
  belongs_to :user
  belongs_to :message 
  validates_uniqueness_of :user, scope: :message
end

class CommentLike
  include DataMapper::Resource
  property :id,         Serial
  belongs_to :user
  belongs_to :comment 
  validates_uniqueness_of :user, scope: :comment
end

class User
  include DataMapper::Resource
  property :id,       Serial
  property :name,     String, required: true
  property :password, String, required: true
  
  #has 1, :userProfile
  has n, :subscriptions_out, "Subscription", :child_key => [ :from_user_id ]
  #has n, :subscriptions_in,  "Subscription"
  has n, :followings, "User", :through => :subscriptions_out, :via => :to_user
  validates_uniqueness_of :name
  #validates_length_of :name, :within => 1..16
    
  def self.find_by_name(name)
    self.first(:name => name)
  end
  
  def self.find_by_id(id)
    self.first(:id => id)
  end
end

class Subscription
  include DataMapper::Resource
  property :id, Serial
  belongs_to :from_user, "User"
  belongs_to :to_user,   "User"
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

def get_message_likes(text)
  likes = text.messageLikes or text.commentLikes
  case likes.length
  when 0
    return "No likes."
  when 1
    return likes[0].user.name + " likes this."
  when 2
    return likes[0].user.name + " and " + likes[1].user.name + " like this."
  else
    return (likes[0..(likes.length-2)].map { |like| like.user.name }.join(", ")).to_s + ", and " + (likes[(likes.length-1)].user.name.to_s) + " like this.";
  end
end

def get_subscribed_to(user)
  subs = user.followings
  case subs.length
  when 0
    return "no one"
  when 1
    return subs[0].name
  when 2
    return subs[0].name + " and " + subs[1].name
  else
    return (subs[0..(subs.length-2)].map { |subscription| subscription.name }.join(", ")).to_s + ", and " + (subs[subs.length-1].name.to_s)
  end
end

get("/") do
  messages = Message.all(order: :created_at.desc)
  comments = Comment.all(order: :created_at.desc)
  users = User.all()
  user = User.find_by_id(session[:user_id])
  erb(:index, locals: { messages: messages, comments: comments, users: users, loggedUser: user } )
end

get("/users/*") do |userId|
  user = User.get(userId)
  if user != nil then
    erb(:user_profile, locals: { user: user, loggedUser: User.find_by_id(session[:user_id]) } )
  else 
    redirect("/")
  end
end

post ("/messageLike/*/*") do |id,userId|
  new_like = MessageLike.create(message: Message.get(id), user: User.get(userId));
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
  new_like = CommentLike.create(comment: Comment.get(id), user: User.get(userId));
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

post("/subscribe/*/*") do |from,to|
  subscription = Subscription.create(from_user: User.get(from), to_user: User.get(to))
  redirect("/")
end

=begin
post("/signinguest") do
  user = User.find_by_name("guest")
  if user == nil then
    user = User.create(name: "guest", password: "")
  else
    session[:user_id] = user.id
  end
  redirect("/")
end
=end

post("/redirectHome") do
  redirect("/")
end

post("/messages") do
  message = Message.create(body: params["body"], created_at: DateTime.now, shown: 1, user: User.find_by_id(session[:user_id]))
  if message.saved?
    redirect("/")
  else
    erb(:error)
  end
end

post("/comments/*") do |message_id|
  comment = Comment.create(body: params["body"], created_at: DateTime.now, shown: 1, user: User.find_by_id(session[:user_id]), message: Message.get(message_id))
  if comment.saved?
    redirect("/")
  else
    erb(:error)
  end
end
