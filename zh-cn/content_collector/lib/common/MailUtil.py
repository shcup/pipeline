#!/usr/bin/python
#-*-coding:utf-8-*-
#!Author:zhujialong@letv.com
# Modified: 20151117.
import os
import sys
import commands
import datetime
import urllib
import urllib2

class MailUtil(object):
    def __init__(self, tos=None):
        """
            tos为收件人地址，以英文逗号间隔.
            Notice:
                content中，"&"符号会被替换掉.
        """
        self.tos = tos 
        self.check_util_start_time = os.popen('date').read()
    def send_short_msg(self, msg, phone_num):
        url_prefix = "http://10.182.63.85:8799/warn_messages?"
        args = {'m':msg, 'p':phone_num}
        url = url_prefix + urllib.urlencode(args)
        try:
            urllib2.urlopen(url)
        except urllib2.HTTPError, e:
            pass

    def get_base_info(self):
        ip = os.popen("/sbin/ifconfig  | grep  'inet addr:' | grep -v '127.0.0.1' | cut -d: -f2 | awk '{ print $1}'").read()
        user = os.popen('whoami').read()
        cur_dir = os.popen("pwd").read()
        now_date = os.popen('date').read()
        ret = "user: " + str(user) + \
                "ip: " + str(ip) + \
                "cur_dir: " + str(cur_dir) + \
                "date: " + str(now_date) + \
                "check_util_start_time: " + str(self.check_util_start_time)
        return ret

    def send_msg(self,subject=None, content=None, tos=None, with_base_info=True, and_symbol_replacement="|", backslash_rep="'", print_info=True, phone_list=13120218846):
        if tos is None:
            tos = self.tos
        if tos is None:
            raise Exception("MailUtil have No tos(mail to address)!")
        if with_base_info:
            content = content + "\n\n--------------\n" + self.get_base_info() 
        if content.find("&") >= 0:
            content = content.replace("&",and_symbol_replacement)
        if content.find("`") >= 0:
            content = content.replace("`", backslash_rep)

        cmd = 'curl -X POST http://10.154.29.168/mail.php -d "content='+ content + '&tos=' + tos + '&subject=' + subject + '"'
        status, output = commands.getstatusoutput(cmd)

        result_info = "MailUtil send_mail \"%s\" to %s status: %s, time:%s." % (subject, tos, str(status), str(datetime.datetime.now()))
        if int(status) != 0:
            error_info = "Error in " + result_info + "\nMail content:\n" + content
            raise Exception(error_info)
        else:
            if print_info:
                sys.stderr.write(result_info + "\n")
        for phone in phone_list.split(','):
            self.send_short_msg(content, phone)
        return status,output

    def send_mail(self,subject=None, content=None, tos=None, with_base_info=True, and_symbol_replacement="|", backslash_rep="'", print_info=True):
        """
            由于运维提供的邮件工具中，使用"&"符号分隔字段，因此，content中不能包含该符号，否则邮件发送不完整。
        """
        if tos is None:
            tos = self.tos
        if tos is None:
            raise Exception("MailUtil have No tos(mail to address)!")
        if with_base_info:
            content = content + "\n\n--------------\n" + self.get_base_info() 
        if content.find("&") >= 0:
            content = content.replace("&",and_symbol_replacement)
        if content.find("`") >= 0:
            content = content.replace("`", backslash_rep)

        cmd = 'curl -X POST http://10.154.29.168/mail.php -d "content='+ content + '&tos=' + tos + '&subject=' + subject + '"'
        status, output = commands.getstatusoutput(cmd)

        result_info = "MailUtil send_mail \"%s\" to %s status: %s, time:%s." % (subject, tos, str(status), str(datetime.datetime.now()))
        if int(status) != 0:
            error_info = "Error in " + result_info + "\nMail content:\n" + content
            raise Exception(error_info)
        else:
            if print_info:
                sys.stderr.write(result_info + "\n")
        return status,output

        
def test():
    tos = None
    tos = "zhujialong@letv.com"
    mail_util = MailUtil(tos=tos)

    subject = "test_sub"
    content = "test_content"
    #with_base_info = False 
    with_base_info = True 

    ret = mail_util.send_mail(subject=subject,content=content, with_base_info=with_base_info)
    print "test ret:",ret

def test2():
    MailUtil().send_mail("test1","test2","zhujialong@letv.com,guoxudong@letv.com")

if __name__=="__main__":
    ########### Notice #############
    ## 外部调用: 此处会被/data/programs/common/shell/sh_check_util.sh中的sendmail命令调用，不能删!
    ################################
    if len(sys.argv) >= 3:
        mail_subject = sys.argv[1]
        mail_content = sys.argv[2]
        mail_to_list = sys.argv[3]
        if len(sys.argv) >= 5:
            print "debug: ", len(sys.argv), sys.argv[5]
            phone_list = sys.argv[5]
            print_info = True if len(sys.argv) > 4 and sys.argv[4] == "True" else False
            MailUtil().send_msg(mail_subject,mail_content,mail_to_list, print_info=print_info, phone_list=phone_list)
            sys.exit(0)
        print_info = True if len(sys.argv) > 4 and sys.argv[4] == "True" else False
        MailUtil().send_mail(mail_subject,mail_content,mail_to_list, print_info=print_info)
    else:
        test2()
