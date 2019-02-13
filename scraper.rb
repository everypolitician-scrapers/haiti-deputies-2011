#!/bin/env ruby
# encoding: utf-8
# frozen_string_literal: true

require 'pry'
require 'scraped'
require 'scraperwiki'

require 'open-uri/cached'
OpenURI::Cache.cache_path = '.cache'

def noko_for(url)
  Nokogiri::HTML(open(url).read)
end

def members_data(url)
  noko = noko_for(url)

  noko.xpath('//h4[contains(.,"PARTEMENT")]').flat_map do |dep|
    dep.xpath('following-sibling::table[1]//tr[td]').map do |tr|
      tds = tr.css('td')

      circ = tds[1].text.tidy.sub('unique circ', '1è circ').sub('circ. unique', '1è circ').sub('1ère circ.', '1è circ')
      cap = circ.match(/(.*):\s*(\d+)è\.?\s*circ\.?\s*(.*)/) or binding.pry

      area = {
        departement: dep.text.tidy.sub('DÉPARTEMENT ', '').sub(/^(du|de l.)\s*/, ''),
        district:    cap[1],
        circ_id:     cap[2],
        circ:        cap[3],
      }
      area[:district] = 'Saint Marc' if area[:district] == 'St. Marc'
      area[:id] = 'ocd-division/country:ht/departement:%s/arrondissement:%s/circonscription:%s' %
                  %i[departement district circ_id].map { |i| area[i].downcase.tr(' ', '_') }

      {
        name:    tds[0].text.tidy.sub('Siège vacant dû au décès de ', '').sub(/ \(.*?\)/, ''),
        region:  dep.text.tidy,
        area_id: area[:id],
        area:    area[:circ],
        party:   tds[2].text.tidy,
        term:    '2011',
        source:  url,
      }
    end
  end
end

data = members_data('https://www.haiti-reference.com/pages/plan/politique/pouvoir-legislatif/49eme-legislature/')
data.each { |mem| puts mem.reject { |_, v| v.to_s.empty? }.sort_by { |k, _| k }.to_h } if ENV['MORPH_DEBUG']

ScraperWiki.sqliteexecute('DROP TABLE data') rescue nil
ScraperWiki.save_sqlite(%i[name area_id], data)
