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
  property :creator,    String,   required: true, default: "Tony Swan"
  
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

class Comment
  include DataMapper::Resource
  property :id,         Serial
  property :body,       Text,     required: true
  property :created_at, DateTime, required: true
  property :likes,      Integer,  required: true
  property :dislikes,   Integer,  required: true
  property :shown,      Integer,  required: true
  property :creator,    String,   required: true, default: "Tony Swan"
  
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



get("/") do
  records = Message.all(order: :created_at.desc)
  records2 = Comment.all(order: :created_at.desc)
  erb(:index, locals: { messages: records, comments: records2 })
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

post("/messages") do

  message_body = params["body"]
  c = params["creator"].to_s
  if c == "" or c.include? " " then
    c = "Tony Swan"
  end
  
  message = Message.create(body: params["body"], created_at: DateTime.now, likes: 0, dislikes: 0, shown: 1, creator: c)

  if message.saved?
    redirect("/")
  else
    erb(:error)
  end
end

post("/comments/*") do |id|
  
  c = params["creator"].to_s
  if c == "" or c.include? " " then
    c = "Tony Swan"
  end
  
  comment = Comment.create(body: params["body"], created_at: DateTime.now, likes: 0, dislikes: 0, shown: 1, creator: c, parentId: id)
  
  if comment.saved?
    redirect("/")
  else
    erb(:error)
  end
  
end
