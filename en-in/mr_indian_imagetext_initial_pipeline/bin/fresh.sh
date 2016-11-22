#/usr/bin

rm -f mr_indian_handler_main
wget http://10.11.145.39:8000/repository/git/search_and_rec/build64_release/shared/pipeline/tools/mr_indian_handler_main
chmod 755 mr_indian_handler_main
exit


rm -f inlink_based_normalize_handler_ind_main
wget http://10.11.145.39:8000/repository/git/search_and_rec/build64_release/shared/pipeline/indian_imagetext_normalize_handler/inlink_based_normalize_handler_ind_main
chmod 755 inlink_based_normalize_handler_ind_main
exit


rm -f mr_crawl_log_convert_main
wget http://10.11.145.39:8000/repository/git/search_and_rec/build64_release/shared/pipeline/tools/mr_crawl_log_convert_main
chmod 755 mr_crawl_log_convert_main

rm -f mr_crawl_hash_filter
wget http://10.11.145.39:8000/repository/git/search_and_rec/build64_release/shared/pipeline/tools/mr_crawl_hash_filter
chmod 755 mr_crawl_hash_filter


