namespace :scrap do
  require 'open-uri'
  require 'nokogiri'
  require 'flickraw'
  require 'net/http'

  def intial
    oa = YAML::load(ERB.new(IO.read("#{Rails.root}/config/flickr.yml")).result)
    FlickRaw.api_key = oa["key"]
    FlickRaw.shared_secret=oa["secret"]
    token = flickr.get_request_token
    auth_url = flickr.get_authorize_url(token['oauth_token'], :perms => 'delete')

    flickr.get_access_token("72157644199938276-d4bb7f5484b7604b", "7388f59d3910e18a", "539-162-781")


  end


  desc "scrap all members"
  task :all => :environment do
    intial
    #Rake::Task['scrap:members_from_a_group'].execute
    Rake::Task['scrap:groups_from_many_members'].execute
    Rake::Task['scrap:members_from_many_groups'].execute

  end


  desc "scrap members from a group ID"
  task :members_from_a_group => :environment do
    intial
    #groups = ["38514992@N00"]
    # Save group
    #groups.each do |id|
      #gr = flickr.groups.getInfo(:group_id => "#{id}")
      # Save first group
#      if !check_group_exist?(id)
#        group = Group.new
#        group.nsid = id
#        group.name = gr["name"]
#        group.total_members = gr["members"]
#        group.save
#      end
      member_from_group_id("38514992@N00")
    #end
   
  end


  desc "scrap members from a group ID"
  task :members_from_a_group_id => :environment do
    intial
    group_id = "52240744699@N01"
    # Save group
    total_pages = 247
    current_page = 228

    while current_page <= total_pages
      begin
        puts "fetching at current page #{current_page} of group id #{group_id}"
        members = flickr.groups.members.getList(:group_id => "#{group_id}", :page => current_page)
        members.each do |m|
          save_member_exists(m, group_id)
        end
      rescue => e
        write_to_log(e)
        write_to_log("fetching at current page #{current_page} of group id #{group_id}")
      end
      current_page = current_page + 1
    end
  end


  desc "scrap groups from a many members"
  task :groups_from_many_members => :environment do
    offset = 12300
    current_page = 124
    per_page = 100
    total_members = Member.count
    total_pages = (total_members / 100) + 1
    while current_page <= total_pages
      members =  Member.limit(per_page).order("id").offset(offset)
      members.each do |member|
        group_from_member_id(member.nsid)
      end
      offset = offset + per_page
      current_page = current_page + 1
    end
  end

  desc "scrap members from many groups"
  task :members_from_many_groups => :environment do
    intial
    offset = 381
    current_page = 4
    per_page = 100
    total_pages = 2670  
    while current_page <= total_pages
      groups = Group.limit(per_page).order("id").offset(offset)
      groups.each do |gr|
        member_from_group_id(gr.nsid)
      end
      offset = offset + per_page
      current_page = current_page + 1
    end
  end

  
  desc "scrap members from many groups"
  task :members_from_many_groups_task2 => :environment do
    intial
    offset = 1309
    current_page = 14
    per_page = 100
    total_pages = 2670
    while current_page <= total_pages
      groups =  Group.limit(per_page).order("id").offset(offset)
      groups.each do |gr|
        member_from_group_id(gr.nsid)
      end
      offset = offset + per_page
      current_page = current_page + 1
    end
  end

  
  desc "scrap email, website"
  task :member_information => :environment do
    offset = 1041201
    current_page = 10412
    #per_page = 100
    #total_entries = Member.count
    #total members = 500000
    total_pages = 15000
    while current_page <= total_pages
      members =  Member.limit(100).order("id").offset(offset)
      members.each do |member|
        begin
          doc = Nokogiri::HTML(open("https://www.flickr.com/people/#{member.nsid}"))
          puts "Fetching email of user nsid = #{member.nsid}, at page #{current_page}"
          #member.website = doc.search("a[@rel= 'nofollow me']").first["href"] rescue nil
          content = doc.css("#a-bit-more-about > dl")
          content.reverse.each do |t|
            if (t.search("dt").text == "Email:")
              email = t.search("dd").text.gsub(" [at] ", "@")
              puts "verifying email:#{email}"
              member.email = email if verify_email(email)
              break
            end
          end
          member.save
        rescue => e
          write_to_email_log(e)
          write_to_email_log("Fetching email, website, facebook link of user nsid = #{member.nsid}, at position #{member.id}")
        end
      end
     
      offset = offset + 100
      current_page = current_page + 1
    end
  end



  def verify_email(email)
    begin
      url = "http://api.verify-email.org/api.php?usr=lensculture&pwd=demo123&check=" + email
      uri = URI(url)
      http = Net::HTTP.new(uri.host, uri.port)
      request = Net::HTTP::Get.new(uri.request_uri)
      response = http.request(request)
      parsed_response = JSON.parse(response.body)
      return parsed_response["verify_status"].to_i == 1
    rescue => e
      write_to_email_log(e)
      write_to_email_log("verify error at email #{email}")
    end
  end

  # Scrapping member from a group id
  def member_from_group_id(group_id)
    #scrap first page
    begin
      puts "fetching group ID #{group_id}"
      members = flickr.groups.members.getList(:group_id => "#{group_id}")
      members.each do |m|
        #store member
        save_member(m, group_id)
      end
      #scrap next page
      total_pages = members.pages
      current_page = 2
      while current_page <= total_pages
        begin
          puts "fetching at current page #{current_page} of group id #{group_id}"
          members = flickr.groups.members.getList(:group_id => "#{group_id}", :page => current_page)
          members.each do |m|
            save_member(m, group_id)
          end
        rescue => e
          write_to_log(e)
          write_to_log("fetching at current page #{current_page} of group id #{group_id}")
        end
        current_page = current_page + 1
      end
    rescue => e
      write_to_log(e)
    end
  end


  def save_member(member, group_id)
    group = Group.find_by_nsid(group_id)
    member_nsid = member["nsid"]
    if check_member_exist?(member_nsid)
      mem = Member.find_by_nsid(member_nsid)
      mem.groups << group
      mem.save
      
    else
      mem = Member.new
      mem.nsid = member_nsid
      mem.username = member["username"]
      mem.realname =  member["realname"]
      mem.membertype = member["membertype"]
      mem.groups << group
      mem.save
    end

  end
  def save_member_exists(member, group_id)
    group = Group.find_by_nsid(group_id)
    member_nsid = member["nsid"]
    if check_member_exist?(member_nsid)
      if !check_member_exists_in_group?(group, member_nsid)
        mem = Member.find_by_nsid(member_nsid)
        mem.groups << group
        mem.save
      end
    else
      mem = Member.new
      mem.nsid = member_nsid
      mem.username = member["username"]
      mem.realname =  member["realname"]
      mem.membertype = member["membertype"]
      mem.groups << group
      mem.save
    end
  end

  def group_from_member_id(member_id)
    puts "Fetching user ID #{member_id}"
    groups  = flickr.people.getGroups(:user_id => member_id) rescue nil
    if !groups.nil?
      groups.each do |group|
        save_group(group, member_id)
      end
    end
  end

  def save_group(group, member_id)
    member = Member.find_by_nsid(member_id)
    group_nsid = group["nsid"]
    if check_group_exist?(group_nsid)
      gr = Group.find_by_nsid(group_nsid)
      gr.members << member
      gr.save
    else
      gr = Group.new
      gr.nsid = group_nsid
      gr.name = group["name"]
      gr.total_members = group["members"]
      gr.members << member
      gr.save
    end

  end

  def check_member_exist?(nsid)
    Member.exists?(nsid: nsid)
  end

  def check_member_exists_in_group?(group, nsid)
    group.members.exists?(nsid: nsid)
  end

  def check_group_exist?(nsid)
    Group.exists?(nsid: nsid)
  end
  

  def write_to_log(error)
    out = File.open("#{Rails.root}/log/flickr.log","a");
    out << error
    out << "\n"
    out.close
  end

  def write_to_email_log(error)
    out = File.open("#{Rails.root}/log/flickr_email.log","a");
    out << error
    out << "\n"
    out.close
  end
end
