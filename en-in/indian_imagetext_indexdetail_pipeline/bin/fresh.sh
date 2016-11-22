rm -f convert_sst_to_fbs
wget http://10.11.145.39:8000/repository/git/search_and_rec/build64_release/recommendation/online/engine/common/tools/convert_sst_to_fbs
chmod 755 convert_sst_to_fbs
exit


rm -f file_read_tool_main
wget http://10.11.145.39:8000/repository/git/search_and_rec/build64_release/shared/pipeline/tools/file_read_tool_main
chmod 755 file_read_tool_main
exit



rm -f recommendation_index_builder_main
wget http://10.11.145.39:8000/repository/git/search_and_rec/build64_release/shared/pipeline/tools/recommendation_index_builder_main
chmod 755 recommendation_index_builder_main
exit

rm -f mr_aggregate_result_merge
wget http://10.11.145.39:8000/repository/git/search_and_rec/build64_release/shared/pipeline/tools/mr_aggregate_result_merge
chmod 755 mr_aggregate_result_merge
exit

rm -f document_inc_related_main
wget http://10.11.145.39:8000/repository/git/search_and_rec/build64_release/shared/pipeline/tools/document_inc_related_main
chmod 755 document_inc_related_main


rm -f document_cluster_int_main
wget http://10.11.145.39:8000/repository/git/search_and_rec/build64_release/shared/pipeline/tools/document_cluster_int_main
chmod 755 document_cluster_int_main

exit


rm -f recommendation_detail_builder_main
wget http://10.11.145.39:8000/repository/git/search_and_rec/build64_release/shared/pipeline/tools/recommendation_detail_builder_main
chmod 755 recommendation_detail_builder_main

exit
rm -f sst_flat_buffers_converter_main
wget http://10.11.145.39:8000/repository/git/search_and_rec/build64_release/recommendation/online/engine/common/tools/sst_flat_buffers_converter_main
chmod 755 sst_flat_buffers_converter_main

rm -f convert_sst_to_fbs
wget http://10.11.145.39:8000/repository/git/search_and_rec/build64_release/recommendation/online/engine/common/tools/convert_sst_to_fbs
chmod 755 convert_sst_to_fbs

rm -f mr_aggregate_data_collector
wget http://10.11.145.39:8000/repository/git/search_and_rec/build64_release/shared/pipeline/tools/mr_aggregate_data_collector
chmod 755 mr_aggregate_data_collector


