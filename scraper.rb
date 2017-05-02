#!/bin/env ruby
# encoding: utf-8
# frozen_string_literal: true

require 'pry'
require 'scraped'
require 'scraperwiki'

# require 'open-uri/cached'
# OpenURI::Cache.cache_path = '.cache'
require 'scraped_page_archive/open-uri'

def noko_for(url)
  Nokogiri::HTML(open(url).read)
end

def scrape_list(url)
  noko = noko_for(url)

  noko.xpath('//p[@class="pagetitle" and contains(.,"PARTEMENT")]').each do |dep|
    dep.xpath('following-sibling::table[1]/tr').drop(1).each do |tr|
      tds = tr.css('td')

      circ = tds[1].text.tidy.sub('unique circ', '1è circ').sub('circ. unique', '1è circ')
      (cap = circ.match(/(.*):\s*(\d+)è\.?\s*circ\.?\s*(.*)/)) || raise("Can't parse area: #{tds[1].text}")

      area = {
        departement: dep.text.tidy.sub('DÉPARTEMENT ', '').sub(/^(du|de l.)\s*/, ''),
        district:    cap[1],
        circ_id:     cap[2],
        circ:        cap[3],
      }
      area[:district] = 'Saint Marc' if area[:district] == 'St. Marc'
      area[:id] = 'ocd-division/country:ht/departement:%s/arrondissement:%s/circonscription:%s' %
                  %i[departement district circ_id].map { |i| area[i].downcase.tr(' ', '_') }

      data = {
        name:    tds[0].text.tidy.sub('Siège vacant dû au décès de ', ''),
        region:  dep.text.tidy,
        area_id: area[:id],
        area:    area[:circ],
        party:   tds[2].text.tidy,
        term:    '2011',
        source:  url,
      }
      ScraperWiki.save_sqlite(%i[name area_id], data)
    end
  end
end

ScraperWiki.sqliteexecute('DELETE FROM data') rescue nil
scrape_list('https://www.haiti-reference.com/politique/legislatif/49eme_legis.php')
