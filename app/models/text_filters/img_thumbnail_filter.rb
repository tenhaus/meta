module TextFilters
  class ImgThumbnailFilter < HTML::Pipeline::Filter

    def call
      doc.css('img').each do |element|
        if context[:firesize_url] && element['src']
          element['src'] = File.join(context[:firesize_url], element['src'])
        end
        element['class'] = [element['class'], 'img-rounded'].compact.join(' ')
      end
      doc
    end

  end
end
