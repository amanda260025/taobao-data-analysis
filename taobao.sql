#1、数据清洗
#1.1 删除重复值
select *
from userbehavior
group by user_id, item, category,time
having count(user_id)>1;
#数据中不存在重复记录

#1.2、查看缺失值
select count(user_id),count(item),count(category),count(behavior),count(time)
from userbehavior;
#不存在缺失值，数据质量高

#1.3、时间格式转换
# 新增date、hour时间字段
alter table userbehavior
add date varchar(20),
add hour varchar(20);
# 时间格式转换
UPDATE userbehavior SET date = FROM_UNIXTIME(time,"%Y-%m-%d");
UPDATE userbehavior SET hour = FROM_UNIXTIME(time,"%H");
UPDATE userbehavior SET time = FROM_UNIXTIME(time);

UPDATE userbehavior SET time = SUBSTRING_INDEX(time,'.',1);

#1.4、过滤异常值
DELETE FROM userbehavior
WHERE date < '2017-11-25' or date > '2017-12-03';


#2、数据分析
#2.1、基于用户行为转化漏斗模型分析用户行为
#常见电商指标
SELECT count(DISTINCT user_id) as UV,
	   sum(case when behavior='pv' then 1 else 0 end) as PV,
	   sum(case when behavior='buy' then 1 else 0 end) as Buy,
	   sum(case when behavior='cart' then 1 else 0 end) as Cart,
	   sum(case when behavior='fav' then 1 else 0 end) as Fav,
	   sum(case when behavior='pv' then 1 else 0 end)/count(DISTINCT user_id) as 'PV/UV'
FROM userbehavior;
#访问用户总数（UV）：9739
#页面总访问量（PV）：895636
#9天时间内平均每人页面访问量（UV/PV）：约为92次

#复购率计算
SELECT 
	sum(case when buy_amount>1 then 1 else 0 end) as "复购总人数",
	count(user_id) as "购买总人数",
	sum(case when buy_amount>1 then 1 else 0 end)/count(user_id) as "复购率"
FROM
	(SELECT *,count(behavior) as buy_amount
	FROM userbehavior
	WHERE behavior = 'buy'
	GROUP BY user_id) a;
#复购率高达66.21%，反映淘宝的用户忠诚度较高。

#跳失率：

SELECT count(*) as "仅访问一次页面的用户数"
FROM
	(SELECT user_id
	FROM userbehavior
	GROUP BY user_id
	HAVING count(behavior)=1) a 
#9天时间内，没有一名用户仅浏览一次页面就离开淘宝，跳失率为0。反映出商品或者商品详情页的内容对于用户具有足够的吸引力，让用户在淘宝驻留。

# 用户总行为漏斗
SELECT behavior,COUNT(*)
FROM userbehavior
GROUP BY behavior
order by behavior desc;

# 独立访客转化漏斗
SELECT behavior,count(DISTINCT user_id)
FROM userbehavior
GROUP BY behavior
ORDER BY behavior DESC;

#2.2、从时间维度分析用户行为
#每天用户的行为分析
SELECT 
	date,
	count(DISTINCT user_id) as '每日用户数',
	sum(case when behavior='pv' then 1 else 0 end) as '浏览数',
	sum(case when behavior='cart' then 1 else 0 end) as '加购数',
	sum(case when behavior='fav' then 1 else 0 end) as '收藏数',
	sum(case when behavior='buy' then 1 else 0 end) as '购买数'
FROM userbehavior
GROUP BY date;
#11月25日至12月1日，数据波动变化范围很小，在12月2-3日（周末），各项数据指标明显上涨，高于前7天的各项数据指标。由于在上一个周末（11月25-26日）的各项数据指标并未存在明显涨幅，因此推测在12月2-3日数据指标上涨可能与淘宝双12预热活动相关。


# 每时的用户行为分析
SELECT 
	hour,
	count(DISTINCT user_id) as '每时用户数',
	sum(case when behavior='pv' then 1 else 0 end) as '浏览数',
	sum(case when behavior='cart' then 1 else 0 end) as '加购数',
	sum(case when behavior='fav' then 1 else 0 end) as '收藏数',
	sum(case when behavior='buy' then 1 else 0 end) as '购买数'
FROM userbehavior
GROUP BY hour;
#在凌晨2-5点左右，各项数据指标进入低谷期；在9-18点之间，数据呈现一个小高峰，波动变化较小；在20-23点间，各数据指标呈现一个大高峰，并且在21点左右达到每日数据最大峰值，数据的变化趋势比较符合正常用户的作息规律。



#2.2、从商品维度分析用户行为
#商品排行榜分析
SELECT item, count(behavior) as '购买次数'
FROM userbehavior
WHERE behavior='buy'
GROUP BY item 
ORDER BY count(behavior) DESC
limit 10;
#在被下单的17565件商品中，单个商品销量最多不超过17次，且仅有5件商品销量超过10次，反映出在分析的数据集中，并没有出现卖的比较火爆的商品。

# 商品浏览量排行榜前10
SELECT item, count(behavior) as '浏览次数'
FROM userbehavior
WHERE behavior='pv'
GROUP BY item 
ORDER BY count(behavior) DESC
limit 10;

# 商品销量榜单与浏览量榜单表连接
SELECT a.item,a.`购买次数`,b.`浏览次数`
FROM 
(SELECT item, count(behavior) as '购买次数'
FROM userbehavior
WHERE behavior='buy'
GROUP BY item 
ORDER BY count(behavior) DESC
LIMIT 10) a 
LEFT JOIN
(SELECT item, count(behavior) as '浏览次数'
FROM userbehavior
WHERE behavior='pv'
GROUP BY item 
ORDER BY count(behavior) DESC
limit 10) b on a.item=b.item;
#商品销量榜单与商品浏览量榜单之间对应性差，反映浏览量高的商品其销量不一定高，销量高的商品其浏览量不一定高，因此需要同时结合销量与浏览量两个维度去进行分析。

#“二八定律”or“长尾理论”分析
# 按照商品销量对商品进行分类统计
SELECT a.`购买次数`, count(a.item) as '商品量'
FROM
	(SELECT item, count(behavior) as '购买次数'
	FROM userbehavior
	WHERE behavior='buy'
	GROUP BY item 
	ORDER BY count(behavior) DESC) a 
GROUP BY a.`购买次数`
ORDER BY count(a.item) DESC;
#在被下单的17565件商品中，只购买一次的商品有15536件，占下单总商品的88.45%，说明在互联网环境下，以淘宝为代表的电商平台，其商品售卖主要是依靠长尾商品的累计效应，并非爆款商品的带动。