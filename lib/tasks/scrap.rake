namespace :scrap do
  require 'open-uri'
  require 'nokogiri'
  require 'flickraw'

  desc "=======runs in all environments"
  task :groups_members => :environment do   
    oa = YAML::load(ERB.new(IO.read("#{Rails.root}/config/flickr.yml")).result)
    FlickRaw.api_key = oa["key"]
    FlickRaw.shared_secret=oa["secret"]
    #token = flickr.get_request_token
    #auth_url = flickr.get_authorize_url(token['oauth_token'], :perms => 'delete')
    flickr.get_access_token("72157641242906225-b1233f29c2209b26", "d1f3f888314cd20e", "119-459-899")
    groups = ["701449@N21","16978849@N00"]
    groups.each do |group|
      data = flickr.groups.members.getList(:group_id => "#{group}")
      data.each do |d|
        member = Member.new()
        member.nsid = d["nsid"]
        member.email = d["email"] rescue nil
        member.username = d["username"]
        member.realname =  d["realname"]
        member.membertype = d["membertype"]
        member.save
      end

      pages = data.pages
      puts "======================total page", pages
      page = 2
      while page <= pages
        puts "======================group_id, page", group, pages
        data = flickr.groups.members.getList(:group_id => "701449@N21", :page => page + 1)
        data.each do |d|
          member = Member.new()
          member.nsid = d["nsid"]
          member.email = d["email"] rescue nil
          member.username = d["username"]
          member.realname =  d["realname"]
          member.membertype = d["membertype"]
          member.save
        end
        page = page + 1
      end
    end
    
    
  end

  desc "++++=======scrapping email"
  task :member => :environment do
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
