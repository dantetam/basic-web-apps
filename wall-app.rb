require "sinatra"     # Load the Sinatra web framework
require "data_mapper" # Load the DataMapper database library

require "./database_setup"
require "dm-validations";

require "tumblr_client";
require "json";

require "net/http"

#An announcement to all subscribers
class Message
  include DataMapper::Resource
  property :id,         Serial
  property :body,       Text,     required: true
  property :created_at, DateTime, required: true
  property :shown,      Integer,  required: true
  #property :type,       Integer,  required: true #0: created by a user, #1 (or any other number): sent to the user's inbox
  
  has n, :comments
  has n, :messageLikes
  belongs_to :user, "User"
  #validates_length_of :name, :min => 1
  
  def hide()
    self.shown = 0
  end
end

#The user's copy of the announcement
=begin
class InboxMessage
  include DataMapper::Resource
  
  
end
=end

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

class TumblrLike
  include DataMapper::Resource
  
  property :id, Serial
  belongs_to :user,        "User"
  belongs_to :tumblr_post, "TumblrPost"
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

class Subscription
  include DataMapper::Resource
  property :id,          Serial
  belongs_to :from_user, "User"
  belongs_to :to_user,   "User"
  
  validates_uniqueness_of :from_user, scope: :to_user
end

class User
  include DataMapper::Resource
  property :id,       Serial
  property :name,     String, required: true
  property :password, String, required: true
  
  #has 1, :userProfile
  
  has n, :messages,             "Message"
  
  has n, :subscriptions_out,    "Subscription", :child_key => [ :from_user_id ]
  has n, :followings,           "User",         :through => :subscriptions_out, :via => :to_user
  has n, :inbox_messages,       "Message",      :through => :followings, :via => :messages
  
  has n, :tumblr_subscriptions, "TumblrSubscription"
  
  has n, :tumblr_likes,         "TumblrLike"
  
  has n, :recent_searches,      "TumblrSearch"
  #has n, :stringy, "String", :through => :tumblr_subscriptions, :via => :tumblr_name
  #has n, :tumblr_followings, "TumblrBlog", :through => :tumblr_subscriptions, :via => :tumblr_name
  #has n, :tumblr_messages,    "Message",              :through => :tumblr_followings, :via => :messages
  
  validates_uniqueness_of :name
  #validates_length_of :name, :within => 1..16
    
  def self.find_by_name(name)
    self.first(:name => name)
  end
  
  def self.find_by_id(id)
    self.first(:id => id)
  end
end

class TumblrComment
  include DataMapper::Resource
  property :id,         Serial
  property :body,       Text,     required: true
  property :created_at, DateTime, required: true
  property :shown,      Integer,  required: true, default: 1
  
  belongs_to :user
  belongs_to :tumblr_post, "TumblrPost"

  def hide()
    self.shown = 0
  end
end

class TumblrPost
  include DataMapper::Resource
  
  property :id,   Serial
  property :body, Text
  
  has n, :comments,        "Comment"
  has n, :likes,           "TumblrLike"
  has n, :tumblr_comments, "TumblrComment"
  
  belongs_to :tumblr_subscription, "TumblrSubscription"
end

class TumblrSubscription
  include DataMapper::Resource
  
  property :id,     Serial
  property :tumblr_name,   String
  #belongs_to :tumblr_followings, "User"
  belongs_to :user, "User"
  
  has n, :tumblr_posts, "TumblrPost"
  
  #validates_uniqueness_of :user, scope: :tumblr_name
end

class TumblrSearch
  include DataMapper::Resource
  
  property :id,          Serial
  property :tumblr_name, String
  belongs_to :user, "User"
end

=begin
class TumblrBlog
  include DataMapper::Resource
  
  property :id,          Serial
  property :tumblr_name, String
end
=end

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

source = Net::HTTP.get('stackoverflow.com', '/index.html')
p source

def current_user
  # Return nil if no user is logged in
  return nil unless session[:user_id] != nil
  # If @current_user is undefined, define it by
  # fetching it from the database.
  @current_user = User.find_by_id(session[:user_id])
end

def get_message_likes(text)
  if text.class.name == "Message" or text.class.name == "Comment" then
    likes = text.messageLikes or text.commentLikes
  else
    likes = text.likes
  end
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

def get_user_likes(text)
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

def get_subscribed_tumblr(user)
  subs = user.tumblr_subscriptions
  case subs.length
  when 0
    return "no one"
  when 1
    return subs[0].tumblr_name
  when 2
    return subs[0].tumblr_name + " and " + subs[1].tumblr_name
  else
    return (subs[0..(subs.length-2)].map { |subscription| subscription.tumblr_name }.join(", ")).to_s + ", and " + (subs[subs.length-1].tumblr_name.to_s)
  end
end

# Authenticate via OAuth
$client = Tumblr::Client.new({
  :consumer_key => 'TUlMONefwOLByGWFKJ0C3WZBWxQuvGL6Bky5fZKKHSUQANSYBM',
  :consumer_secret => 'VrOY2THXcRn4gAollP58ymzC4xj2vK37RLwSXOy2nst0TLxVHi',
  :oauth_token => 'oh8aQ3QamqH03X8k2OKmzJsOTYpc3pWAG4cjzstdKqyx4gBia1',
  :oauth_token_secret => 'rI20PdcagdD9LEOej3P5zlCqvwHzClJFlvvaJj8zerhIbtRNUX'
})

#puts $client.info

#A poetry blog on tumblr
#puts $client.posts 'lionofchaeronea.tumblr.com', :type => 'text', :limit => 5, :filter => 'text'

=begin
def tumblr_post(blogname)
  hash = $client.posts blogname, :type => 'text', :filter => 'text'
  hash2 = $client.posts blogname, :type => 'photo'
  return hash["posts"] + hash2["posts"]
end
=end

def tumblr_post(blogname)
  hash = $client.posts blogname, :filter => 'text'
  return hash["posts"]
end

=begin
def tumblr_images(blogname)
  return hash["posts"]
end
=end

get("/") do
  messages = Message.all(order: :created_at.desc)
  comments = Comment.all(order: :created_at.desc)
  users = User.all()
  user = User.find_by_id(session[:user_id])
  if user != nil then
    p user.recent_searches.length
    erb(:index, locals: { 
      messages: user.messages, 
      inbox_messages: user.inbox_messages, 
      comments: comments, 
      users: users, 
      loggedUser: user, 
      tumblr_search: user.recent_searches
    })
  else
    erb(:index, locals: { 
      messages: nil, 
      inbox_messages: nil, 
      comments: comments, 
      users: users, 
      loggedUser: nil, 
      tumblr_search: nil
    })
  end
end

get("/users/*") do |userId|
  user = User.get(userId)
  if user != nil then
    erb(:user_profile, locals: { user: user, loggedUser: User.find_by_id(session[:user_id]) } )
  else 
    redirect("/")
  end
end

get("/tumblr/*") do |tumblr_name|
  blog = $client.blog_info (tumblr_name + ".tumblr.com")
  puts tumblr_name + ".tumblr.com"
  erb(:tumblr_profile, locals: { blog: tumblr_name + ".tumblr.com", client: $client, loggedUser: User.find_by_id(session[:user_id]) } )
end

post("/tumblrSubscribe/*") do |name|
  user = User.find_by_id(session[:user_id])
  p user
  t_sub = TumblrSubscription.new(:user => user, tumblr_name: name)
  t_sub.save
  p t_sub.errors
  tumblr_post(name).each do |pst|
    #puts t_sub.tumblr_name
    p t_sub
    if pst["type"] == "text" then
      t_post = TumblrPost.create(:body => pst["body"].to_s, :tumblr_subscription => t_sub)
      p t_post.errors
      if t_post.saved?
        #p t_sub.tumblr_posts.length
        p "yes"
      else
        p "waffles"
      end
    end
  end
  redirect("/")
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

post ("/tumblrMessageLike/*/*") do |id,userId|
  new_like = TumblrLike.create(:tumblr_post => TumblrPost.get(id), user: User.get(userId));
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
  if from != to then
    subscription = Subscription.create(from_user: User.get(from), to_user: User.get(to))
  end
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

post("/searchUser") do
  user = User.find_by_name(params["username"])
  if user != nil then
    redirect("/users/" << (user.id.to_s))
  else 
    redirect("/")
  end
end

post("/tumblr") do
  puts params["tumblrname"].to_s
  ts = TumblrSearch.new(:user => User.find_by_id(session[:user_id]), :tumblr_name => params["tumblrname"].to_s)
  ts.save
  p ts.errors
  if ts.saved? 
    redirect("/tumblr/" + params["tumblrname"].to_s)
  else
    redirect("/")
  end
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

post("/tumblrMessageComments/*") do |id|
  comment = Comment.create(body: params["body"], created_at: DateTime.now, shown: 1, user: User.find_by_id(session[:user_id]), message: TumblrPost.get(id))
  if comment.saved?
    redirect("/")
  else
    erb(:error)
  end
end
