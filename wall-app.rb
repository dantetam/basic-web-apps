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
  erb(:index, locals: { messages: records })
end

get ("/submitOpinion") do
  records = Message.all(order: :created_at.desc)
  if params["opinion"][0..3] == "Like" 
    message = records[params["opinion"][4..params["opinion"].length].to_i]
    message.addLike()
  elsif params["opinion"][0..3] == "Hate" 
    message = records[params["opinion"][4..params["opinion"].length].to_i]
    message.subLike()
  elsif params["opinion"][0..3] == "Impl" 
    message = records[params["opinion"][4..params["opinion"].length].to_i]
    message.hide()
  end
  message.save
  redirect("/")
end

=begin
get ("/like") do
  records = Message.all(order: :created_at.desc)
  message = records[params["opinion"].to_i]
  message.addLike()
  message.save
end

get ("/hate") do
  records = Message.all(order: :created_at.desc)
  message = records[params["opinion"].to_i]
  message.subLike()
  message.save
end

get ("/implode") do
  redirect("/")
end
=end

post("/messages") do

  message_body = params["body"]
  
  message = Message.create(body: params["body"], created_at: DateTime.now, likes: 0, dislikes: 0, shown: 1)

  if message.saved?
    redirect("/")
  else
    erb(:error)
  end
end
