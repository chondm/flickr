namespace :scrap do
  require 'open-uri'
  require 'nokogiri'
  require 'flickraw'

  desc "scrap members from a group ID"
  task :members_from_a_group => :environment do
    oa = YAML::load(ERB.new(IO.read("#{Rails.root}/config/flickr.yml")).result)
    FlickRaw.api_key = oa["key"]
    FlickRaw.shared_secret=oa["secret"]
    #token = flickr.get_request_token
    #auth_url = flickr.get_authorize_url(token['oauth_token'], :perms => 'delete')
    flickr.get_access_token("72157641286145863-48e482439babd015", "6c1eb69803017375", "148-745-621")

    groups = ["701449@N21","16978849@N00"]
    groups.each do |group|
      data = flickr.groups.members.getList(:group_id => "#{group}")
      data.each do |d|
        member = Member.new()
        member.nsid = d["nsid"] 
        member.username = d["username"]
        member.realname =  d["realname"]
        member.membertype = d["membertype"]
        member.save
      end

      pages = data.pages

      page = 2
      while page <= pages
        puts "======================running at current page",  page
        data = flickr.groups.members.getList(:group_id => "#{group}", :page => page)
        data.each do |d|
          member = Member.new()
          member.nsid = d["nsid"]          
          member.username = d["username"]
          member.realname =  d["realname"]
          member.membertype = d["membertype"]
          member.save
        end
        page = page + 1
      end
    end
    
    
  end

  desc "scrap email, website"
  task :scrap_emai_websites => :environment do
    members = Member.all
    members.each do |member|
      doc = Nokogiri::HTML(open("http://www.flickr.com/people/#{member.nsid}"))
      puts "=====================user_id", member.id
      member.website = doc.css("#a-bit-more-about > dl > dd").search("a[@rel='nofollow me']").first["href"] rescue nil
      content = doc.css("#a-bit-more-about > dl")
      content.each do |t|
        if (t.search("dt").text == "Email:")
          member.email = t.search("dd").text.gsub(" [at] ", "@")
        end
      end
      member.save

    end
  end
end
