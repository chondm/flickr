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
    flickr.get_access_token("72157641686182513-c26fd60d38fbfa45", "bbc2e430d4d8ba2e", "341-085-785")
  end


  desc "scrap all members"
  task :all => :environment do
    intial
    Rake::Task['scrap:members_from_a_group'].execute
    Rake::Task['scrap:groups_from_many_members'].execute
    Rake::Task['scrap:members_from_many_groups'].execute
   
  end



  desc "scrap members from a group ID"
  task :members_from_a_group => :environment do    
    groups = ["701449@N21", "16978849@N00"]
    # Save group
    groups.each do |id|
      gr = flickr.groups.getInfo(:group_id => "#{id}")
      # Save first group
      if !check_group_exist?(id)
        group = Group.new
        group.nsid = id
        group.name = gr["name"]
        group.total_members = gr["members"]
        group.save
      end
      member_from_group_id(id)
    end  
  end


  desc "scrap groups from a many members"
  task :groups_from_many_members => :environment do
    offset = 0
    current_page = 1
    per_page = 100
    total_members = Member.count
    total_pages = (total_members / 100) + 1
    while current_page <= total_pages
      members =  Member.limit(per_page).offset(offset)
      members.each do |member|
        group_from_member_id(member.nsid)
      end
      offset = offset + per_page
      current_page = current_page + 1
    end
  end

  desc "scrap members from many groups"
  task :members_from_many_groups => :environment do
    offset = 0
    current_page = 1
    per_page = 100
    total_groups = Group.count
    total_pages = (total_groups / 100) + 1
    while current_page <= total_pages
      groups =  Group.limit(per_page).offset(offset)
      groups.each do |gr|
        member_from_group_id(gr.nsid)
      end
      offset = offset + per_page
      current_page = current_page + 1
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
        puts "Fetching user ID", member.nsid
        #member.website = doc.css("#a-bit-more-about > dl > dd").search("a[@rel='nofollow me']").first["href"] rescue nil
        member.website = doc.search("a[@rel= 'nofollow me']").first["href"] rescue nil
        content = doc.css("#a-bit-more-about > dl")
        content.reverse.each do |t|          
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

  # Scrapping member from a group id
  def member_from_group_id(group_id)
    #scrap first page
    members = flickr.groups.members.getList(:group_id => "#{group_id}")
    members.each do |m|
      #store member
      if !check_member_exist?(m["nsid"])        
        save_member(m, group_id)
      end
    end

    #scrap next page
    total_pages = members.pages
    current_page = 2
    while current_page <= total_pages
      puts "fetching at current page #{current_page} of group id #{group_id}"
      members = flickr.groups.members.getList(:group_id => "#{group_id}", :page => current_page)
      members.each do |m|
        if !check_member_exist?(m["nsid"])
          save_member(m, group_id)
        end
      end
      current_page = current_page + 1
    end
  end


  def save_member(member, group_id)
    group = Group.find_by_nsid(group_id)
    mem = Member.new
    mem.nsid = member["nsid"]
    mem.username = member["username"]
    mem.realname =  member["realname"]
    mem.membertype = member["membertype"]
    mem.groups << group
    mem.save
  end

  def group_from_member_id(member_id)
    puts "Fetching user ID #{member_id}"
    groups  = flickr.people.getGroups(:user_id => member_id)
    groups.each do |group|
      if !check_group_exist?(group["nsid"])
        save_group(group, member_id)
      end
    end
  end

  def save_group(group, member_id)
    member = Member.find_by_nsid(member_id)
    gr = Group.new
    gr.nsid = group["nsid"]
    gr.name = group["name"]
    gr.total_members = group["members"]
    gr.members << member
    gr.save
  end

  def check_member_exist?(nsid)
    Member.exists?(nsid: nsid)
  end

  def check_group_exist?(nsid)
    Group.exists?(nsid: nsid)
  end
  

end
