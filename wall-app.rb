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
  
  def addLike()
    self.likes += 1
  end
  def subLike()
    self.likes -= 1
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
  
  end
  message.save
  redirect("/")
end

post("/messages") do

  message_body = params["body"]
  
  message = Message.create(body: params["body"], created_at: DateTime.now, likes: 0, dislikes: 0)

  if message.saved?
    redirect("/")
  else
    erb(:error)
  end
end
