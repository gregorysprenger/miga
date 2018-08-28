
# High-end pipelines for SubcladeRunner
module MiGA::SubcladeRunner::Pipeline

  # Run species-level clusterings using ANI>95% / AAI>90%
  def cluster_species
    tasks = {ani95: [:ani_distances, 95.0], aai90: [:aai_distances, 90.0]}
    tasks.each do |k, par|
      # Build ABC files
      abc_path = tmp_file("#{k}.abc")
      ofh = File.open(abc_path, 'w')
      metric_res = project.result(par[0]) or raise "Incomplete step #{par[0]}"
      Zlib::GzipReader.open(metric_res.file_path(:matrix)) do |ifh|
        ifh.each_line do |ln|
          next if ln =~ /^metric\t/
          r = ln.chomp.split("\t")
          ofh.puts "G>#{r[1]}\tG>#{r[2]}\t#{r[3]}" if r[3].to_f >= par[1]
        end
      end
      ofh.close
      # Cluster genomes
      `ogs.mcl.rb -o 'miga-project.#{k}-clades' --abc '#{abc_path}' \
            -t '#{opts[:thr]}'`
    end
    # Propose clades
    ofh = File.open('miga-project.proposed-clades', 'w')
    File.open('miga-project.ani95-clades', 'r') do |ifh|
      ifh.each_line do |ln|
        next if $.==1
        r = ln.chomp.split(',')
        ofh.puts r.join("\t") if r.size >= 5
      end
    end
    ofh.close
  end

  def subclades metric
    src = File.expand_path('utils/subclades.R', MiGA::MiGA.root_path)
    step = :"#{metric}_distances"
    metric_res = project.result(step) or raise "Incomplete step #{step}"
    matrix = metric_res.file_path(:matrix)
    `Rscript '#{src}' '#{matrix}' miga-project '#{opts[:thr]}'`
  end

  def compile
    src = File.expand_path('utils/subclades-compile.rb', MiGA::MiGA.root_path)
    `ruby '#{src}' '.' 'miga-project.class'`
  end
end
