namespace :scrap do
  require 'open-uri'
  require 'nokogiri'
  require 'flickraw'


  def intial
    oa = YAML::load(ERB.new(IO.read("#{Rails.root}/config/flickr.yml")).result)
    FlickRaw.api_key = oa["key"]
    FlickRaw.shared_secret=oa["secret"]
    #token = flickr.get_request_token
    #auth_url = flickr.get_authorize_url(token['oauth_token'], :perms => 'delete')
    flickr.get_access_token("72157641645828894-22400f0dc8daf03d", "ec326339fd618aaf", "876-366-551")
  end


  desc "scrap members from a group ID"
  task :members_from_a_group => :environment do
    
    intial
    groups = ["701449@N21"]#,"16978849@N00"

    # Save group
    groups.each do |g|
      group_hash = flickr.groups.getInfo(:group_id => "#{g}")
      group = Group.new
      group.nsid = group
      group.name = group_hash["name"]
      group.total_members = group_hash["members"]
      group.save

      m = flickr.groups.members.getList(:group_id => "#{g}")
      m.each do |d|
        # Save member from a group
        member = Member.new()
        member.nsid = m["nsid"]
        member.username = m["username"]
        member.realname =  m["realname"]
        member.membertype = m["membertype"]
        member.save
      end

      total_page = m.pages
      current_page = 2
      while current_page <= total_page
        puts "======================running at current page",  current_page
        m = flickr.groups.members.getList(:group_id => "#{g}", :page => current_page)
        data.each do |d|
          member = Member.new()
          member.nsid = m["nsid"]
          member.username = m["username"]
          member.realname =  m["realname"]
          member.membertype = m["membertype"]
          member.save
        end
        current_page = current_page + 1
      end
    end  
    
    #invoke a rake task from another task
    Rake::Task['scrap:members_from_many_groups'].execute
  end

  desc "scrap members from many groups"
  task :members_from_many_groups => :environment do
    offset = 0
    page = 1
    per_page = 100
    total_entries = Group.count
    total_pages = (total_entries / 100) + 1
    while page <= total_pages
      members =  Group.limit(per_page).offset(offset)
      members.each do |member|
        data  = flickr.people.getGroups(:user_id => member.nsid)
        data.each do |d|
          unless check_group_exist?(d["nsid"])
            group = Group.new
            group.nsid = d["nsid"]
            group.name = d["name"]
            group.total_members = d["members"]
            group.members << member
            group.save
          end
        end
      end
    end
  end

  desc "scrap groups from a many members"
  task :groups_from_many_members => :environment do
    intial
    offset = 0
    page = 1
    per_page = 100
    total_entries = Member.count
    total_pages = (total_entries / 100) + 1
    while page <= total_pages
      members =  Member.limit(per_page).offset(offset)
      members.each do |member|
        puts "=======================", member.nsid
        data  = flickr.people.getGroups(:user_id => member.nsid)
        data.each do |d|
          unless check_group_exist?(d["nsid"])
            group = Group.new
            group.nsid = d["nsid"]
            group.name = d["name"]
            group.total_members = d["members"]
            group.members << member
            group.save
          end
        end
      end
    end

  end

  desc "scrap email, website"
  task :info_member => :environment do
    offset = 0
    page = 1
    per_page = 100
    total_entries = Member.count
    total_pages = (total_entries / 100) + 1
    while page <= total_pages
      members =  Member.limit(per_page).offset(offset)
      members.each do |member|
        doc = Nokogiri::HTML(open("http://www.flickr.com/people/#{member.nsid}"))
        puts "=====================user_id", member.id
        #member.website = doc.css("#a-bit-more-about > dl > dd").search("a[@rel='nofollow me']").first["href"] rescue nil
        member.website = doc.search("a[@rel= 'nofollow me']").first["href"] rescue nil
        content = doc.css("#a-bit-more-about > dl")
        content.reverse.each do |t|
          puts "===============text", t.search("dt").text
          if (t.search("dt").text == "Email:")
            member.email = t.search("dd").text.gsub(" [at] ", "@")
            break
          end
        end
        member.save

      end
      offset = offset + per_page
      page = page + 1
    end

  end




  def check_member_exist?(nsid)
    Member.exists?(nsid: nsid)
  end

  def check_group_exist?(nsid)
    Group.exists?(nsid: nsid)
  end
  

end
